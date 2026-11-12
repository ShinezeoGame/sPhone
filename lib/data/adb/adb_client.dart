import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Erreur renvoyée par le service adb, ou liaison avec lui perdue.
class AdbException implements Exception {
  const AdbException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Client du service adb local (port 5037).
///
/// L'application lui parle directement plutôt que de lancer `adb.exe` à chaque question :
/// c'est instantané, la liste des téléphones arrive en continu sans avoir à interroger,
/// et aucune fenêtre de console n'apparaît.
///
/// Protocole : chaque requête est précédée de sa longueur sur 4 chiffres hexadécimaux ;
/// le service répond `OKAY` ou `FAIL` suivi d'un message.
class AdbClient {
  AdbClient({this.host = '127.0.0.1', this.port = 5037, this.connectTimeout = const Duration(seconds: 2)});

  final String host;
  final int port;
  final Duration connectTimeout;

  /// Vrai si le service répond.
  Future<bool> isAlive() async {
    try {
      await hostRequest('host:version', timeout: const Duration(seconds: 2));
      return true;
    } on Object {
      return false;
    }
  }

  /// Requête au service lui-même (`host:devices-l`, `host:connect:…`) : renvoie sa réponse.
  Future<String> hostRequest(String service, {Duration timeout = const Duration(seconds: 10)}) {
    return _session(timeout, (socket, reader) async {
      await _request(socket, reader, service);
      return utf8.decode(await reader.readBlock(), allowMalformed: true);
    });
  }

  /// Arrête le service. Il coupe la liaison sans toujours répondre : ce n'est pas une erreur.
  Future<void> kill() async {
    try {
      await _session(const Duration(seconds: 2), (socket, reader) => _request(socket, reader, 'host:kill'));
    } on Object {
      // Service déjà arrêté.
    }
  }

  /// Exécute un service sur un téléphone (`shell:…`, `exec:…`, `tcpip:5555`) et renvoie
  /// tout ce qu'il écrit jusqu'à la fermeture de la liaison.
  Future<Uint8List> run(String serial, String service, {Duration timeout = const Duration(seconds: 10)}) {
    return _session(timeout, (socket, reader) async {
      await _request(socket, reader, 'host:transport:$serial');
      await _request(socket, reader, service);
      return reader.readToEnd();
    });
  }

  /// Exécute une commande sur le téléphone et renvoie sa sortie, sans les fins de ligne.
  Future<String> shell(String serial, String command, {Duration timeout = const Duration(seconds: 8)}) async {
    final bytes = await run(serial, 'shell:$command', timeout: timeout);
    return utf8.decode(bytes, allowMalformed: true).trim();
  }

  /// Suit un service qui publie en continu (`host:track-devices-l`) : un événement à
  /// chaque changement. Le flux se termine en erreur si le service s'arrête.
  Stream<String> track(String service) {
    late final StreamController<String> controller;
    Socket? socket;
    _ByteReader? reader;
    var cancelled = false;

    Future<void> pump() async {
      try {
        final s = socket = await _open();
        if (cancelled) return;
        final r = reader = _ByteReader(s);
        await _request(s, r, service);
        while (!cancelled) {
          final block = await r.readBlock();
          if (cancelled) break;
          controller.add(utf8.decode(block, allowMalformed: true));
        }
      } on Object catch (error, stack) {
        if (!cancelled) controller.addError(_wrap(error), stack);
      } finally {
        socket?.destroy();
        if (!controller.isClosed) unawaited(controller.close());
      }
    }

    controller = StreamController<String>(
      onListen: pump,
      onCancel: () {
        cancelled = true;
        reader?.abort();
        socket?.destroy();
      },
    );
    return controller.stream;
  }

  Future<Socket> _open() async {
    try {
      final socket = await Socket.connect(host, port, timeout: connectTimeout);
      socket.setOption(SocketOption.tcpNoDelay, true);
      return socket;
    } on Object catch (error) {
      throw _wrap(error);
    }
  }

  Future<T> _session<T>(Duration timeout, Future<T> Function(Socket socket, _ByteReader reader) body) async {
    final socket = await _open();
    final reader = _ByteReader(socket);
    try {
      return await body(socket, reader).timeout(timeout);
    } on TimeoutException {
      throw const AdbException('Le téléphone ne répond pas.');
    } on AdbException {
      rethrow;
    } on Object catch (error) {
      throw _wrap(error);
    } finally {
      reader.abort();
      socket.destroy();
    }
  }

  /// Envoie une requête et attend `OKAY` ; lève [AdbException] avec le message du service
  /// sur `FAIL`.
  Future<void> _request(Socket socket, _ByteReader reader, String service) async {
    final payload = utf8.encode(service);
    socket.add(ascii.encode(payload.length.toRadixString(16).padLeft(4, '0')));
    socket.add(payload);
    await socket.flush();
    final status = ascii.decode(await reader.read(4), allowInvalid: true);
    if (status == 'OKAY') return;
    if (status == 'FAIL') {
      throw AdbException(utf8.decode(await reader.readBlock(), allowMalformed: true));
    }
    throw AdbException('Réponse inattendue du service adb : $status');
  }

  static AdbException _wrap(Object error) {
    if (error is AdbException) return error;
    if (error is SocketException || error is TimeoutException) {
      return const AdbException('Service adb injoignable.');
    }
    return AdbException(error.toString());
  }
}

/// Lit un nombre exact d'octets dans un flux qui les livre par morceaux quelconques.
class _ByteReader {
  _ByteReader(Stream<Uint8List> source) {
    _subscription = source.listen(
      (chunk) {
        if (chunk.isEmpty) return;
        _chunks.add(chunk);
        _available += chunk.length;
        _wake();
      },
      onError: (Object error) {
        _error ??= error;
        _done = true;
        _wake();
      },
      onDone: () {
        _done = true;
        _wake();
      },
      cancelOnError: true,
    );
  }

  late final StreamSubscription<Uint8List> _subscription;
  final Queue<Uint8List> _chunks = Queue();

  /// Octets déjà consommés dans le premier morceau.
  int _offset = 0;
  int _available = 0;
  bool _done = false;
  Object? _error;
  Completer<void>? _waiter;

  void _wake() {
    final waiter = _waiter;
    _waiter = null;
    waiter?.complete();
  }

  Future<void> _wait() => (_waiter ??= Completer<void>()).future;

  /// Abandonne la lecture : les attentes en cours échouent.
  void abort() {
    if (!_done) {
      _done = true;
      _error ??= const AdbException('Lecture interrompue.');
    }
    unawaited(_subscription.cancel());
    _wake();
  }

  Future<Uint8List> read(int count) async {
    while (_available < count) {
      if (_done) throw _error ?? const AdbException('Le service adb a coupé la liaison.');
      await _wait();
    }
    return _take(count);
  }

  /// Lit un bloc précédé de sa longueur (4 chiffres hexadécimaux).
  Future<Uint8List> readBlock() async {
    final header = ascii.decode(await read(4), allowInvalid: true);
    final length = int.tryParse(header, radix: 16);
    if (length == null) throw AdbException('Longueur invalide reçue du service adb : $header');
    return read(length);
  }

  Future<Uint8List> readToEnd() async {
    while (!_done) {
      await _wait();
    }
    final error = _error;
    if (error != null) throw error;
    return _take(_available);
  }

  Uint8List _take(int count) {
    final out = Uint8List(count);
    var written = 0;
    while (written < count) {
      final chunk = _chunks.first;
      final n = (chunk.length - _offset < count - written) ? chunk.length - _offset : count - written;
      out.setRange(written, written + n, chunk, _offset);
      written += n;
      _offset += n;
      if (_offset == chunk.length) {
        _chunks.removeFirst();
        _offset = 0;
      }
    }
    _available -= count;
    return out;
  }
}
