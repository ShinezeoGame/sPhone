// Essai des vrais programmes embarqués (scrcpy et adb), sans téléphone.
//
// Exécuté par la compilation Windows une fois scrcpy téléchargé ; ignoré ailleurs :
//
//     $env:SPHONE_SCRCPY_DIR = "$PWD\build\scrcpy" ; flutter test test/windows_tools_test.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sphone/data/adb/adb_client.dart';
import 'package:sphone/data/adb/adb_parsers.dart';
import 'package:sphone/data/adb/adb_server.dart';
import 'package:sphone/data/scrcpy.dart';
import 'package:sphone/data/settings.dart';
import 'package:sphone/data/tools.dart';

void main() {
  final enabled = (Platform.environment['SPHONE_SCRCPY_DIR'] ?? '').isNotEmpty;
  final tools = Tools.locate();

  test('les programmes sont trouvés, dans la version attendue', skip: !enabled, () async {
    expect(tools.complete, isTrue, reason: 'scrcpy et adb doivent être dans SPHONE_SCRCPY_DIR');
    final result = await Process.run(tools.scrcpy!, ['--version']);
    expect(result.exitCode, 0);
    expect(result.stdout as String, contains('scrcpy $scrcpyVersion'));
  });

  test('le service adb démarre, répond, publie la liste des téléphones et s\'arrête', skip: !enabled, () async {
    final client = AdbClient();
    final alreadyRunning = await client.isAlive();
    final server = AdbServer(client: client, adbPath: tools.adb);
    await server.ensureRunning();
    expect(server.startedByUs, !alreadyRunning);

    // Aucun téléphone sur la machine de compilation : la liste est vide, mais bien formée.
    expect(parseDevices(await client.hostRequest('host:devices-l')), isEmpty);

    final first = Completer<String>();
    final tracking = client.track('host:track-devices-l').listen((list) {
      if (!first.isCompleted) first.complete(list);
    });
    expect(parseDevices(await first.future.timeout(const Duration(seconds: 5))), isEmpty);
    await tracking.cancel();

    final refused = parseConnectReply(await client.hostRequest('host:connect:127.0.0.1:1'), '127.0.0.1:1');
    expect(refused.ok, isFalse);

    await server.stopIfOwned();
    if (!alreadyRunning) {
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(await client.isAlive(), isFalse);
    }
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('scrcpy accepte tous les arguments que sPhone peut lui passer', skip: !enabled, () async {
    // Sans téléphone, scrcpy s'arrête à la recherche de l'appareil : s'il y arrive, c'est
    // que la ligne de commande a été comprise (une option inconnue échoue avant).
    // Le service adb est démarré d'abord, comme dans l'application : lancé par scrcpy,
    // il hériterait de ses sorties et les garderait ouvertes.
    final server = AdbServer(client: AdbClient(), adbPath: tools.adb);
    await server.ensureRunning();
    for (final settings in [
      const Settings(),
      const Settings(
        quality: Quality.smooth,
        fps: 120,
        windowSize: WindowSize.large,
        keyboard: KeyboardMode.physical,
        audio: false,
        screenOff: true,
        lockOnClose: true,
        alwaysOnTop: true,
      ),
    ]) {
      final process = await startScrcpy(
        tools,
        buildScrcpyArgs(serial: 'TELEPHONE-ABSENT', title: 'sPhone — essai', settings: settings, screenHeight: 1080),
      );
      final output = <String>[];
      final drained = Future.wait([
        process.stdout.transform(utf8.decoder).transform(const LineSplitter()).forEach(output.add),
        process.stderr.transform(utf8.decoder).transform(const LineSplitter()).forEach(output.add),
      ]);
      final code = await process.exitCode.timeout(
        const Duration(seconds: 40),
        onTimeout: () {
          process.kill();
          return -1;
        },
      );
      await drained.timeout(const Duration(seconds: 5), onTimeout: () => const []);
      final log = output.join('\n');
      expect(code, ScrcpyExit.startFailure, reason: log);
      expect(log, contains('Could not find'), reason: log);
      expect(describeStartFailure(output), contains('plus joignable'));
    }
    await server.stopIfOwned();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
