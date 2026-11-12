import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Faux programme pour les tests : il « tourne » jusqu'à ce que le test le termine.
class FakeProcess implements Process {
  FakeProcess(this.executable, this.arguments, this.environment);

  final String executable;
  final List<String> arguments;
  final Map<String, String>? environment;

  final _exit = Completer<int>();
  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  bool killed = false;

  /// Termine le programme avec ce code, après avoir écrit [stderr].
  void finish(int code, {String stderr = ''}) {
    if (_exit.isCompleted) return;
    if (stderr.isNotEmpty) _stderr.add(utf8.encode(stderr));
    unawaited(_stdout.close());
    unawaited(_stderr.close());
    _exit.complete(code);
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    finish(-1);
    return true;
  }

  @override
  int get pid => 4242;

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  IOSink get stdin => throw UnimplementedError();
}

/// Enregistre les programmes lancés au lieu de les exécuter.
class FakeLauncher {
  final List<FakeProcess> started = [];

  FakeProcess get last => started.last;

  Future<Process> call(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
  }) async {
    final process = FakeProcess(executable, arguments, environment);
    started.add(process);
    return process;
  }
}
