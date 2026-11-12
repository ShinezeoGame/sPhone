import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sphone/data/adb/adb_client.dart';
import 'package:sphone/data/adb/adb_server.dart';

import 'support/fake_adb.dart';

const _usb = 'R5TEST\tdevice usb:1-2 product:pa1qxxx model:SM_S931B device:pa1q transport_id:1\n';

void main() {
  late FakeAdb adb;
  late AdbClient client;

  setUp(() async {
    adb = await FakeAdb.start();
    client = AdbClient(port: adb.port);
  });

  tearDown(() => adb.close());

  test('le service répond : isAlive', () async {
    expect(await client.isAlive(), isTrue);
    await adb.close();
    expect(await client.isAlive(), isFalse);
  });

  test('une requête au service renvoie sa réponse', () async {
    adb.setDevices(_usb);
    expect(await client.hostRequest('host:devices-l'), _usb);
    expect(await client.hostRequest('host:connect:192.168.1.20:5555'), 'connected to 192.168.1.20:5555');
  });

  test('un refus du service devient une AdbException avec son message', () async {
    expect(
      () => client.hostRequest('host:nimporte-quoi'),
      throwsA(isA<AdbException>().having((e) => e.message, 'message', 'unknown host service')),
    );
    expect(
      () => client.shell('ABSENT', 'echo'),
      throwsA(isA<AdbException>().having((e) => e.message, 'message', contains('not found'))),
    );
  });

  test('une commande sur le téléphone renvoie sa sortie', () async {
    adb.setDevices(_usb);
    adb.shell['getprop'] = 'R5TEST\n';
    expect(await client.shell('R5TEST', 'getprop ro.serialno'), 'R5TEST');
    expect(adb.requests, containsAllInOrder(['host:transport:R5TEST', 'shell:getprop ro.serialno']));
  });

  test('une sortie binaire volumineuse arrive intacte', () async {
    adb.setDevices(_usb);
    adb.exec = Uint8List.fromList(List.generate(300000, (i) => i % 251));
    final bytes = await client.run('R5TEST', 'exec:screencap -p');
    expect(bytes.length, 300000);
    expect(bytes[250999], 250999 % 251);
  });

  test('le suivi publie chaque changement de la liste', () async {
    final events = <String>[];
    final subscription = client.track('host:track-devices-l').listen(events.add);
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    adb.setDevices(_usb);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    adb.setDevices('');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(events, ['', _usb, '']);
    await subscription.cancel();
  });

  test('le suivi se termine en erreur quand le service s\'arrête', () async {
    final failed = Completer<Object>();
    client.track('host:track-devices-l').listen((_) {}, onError: failed.complete);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await adb.close();
    expect(await failed.future.timeout(const Duration(seconds: 2)), isA<AdbException>());
  });

  group('AdbServer', () {
    test('ne lance rien si le service répond déjà', () async {
      var launched = 0;
      final server = AdbServer(client: client, adbPath: 'adb', launcher: (_, _) async => launched++);
      await server.ensureRunning();
      expect(launched, 0);
      expect(server.startedByUs, isFalse);
    });

    test('lance « adb start-server » puis attend que le service réponde', () async {
      final port = adb.port;
      await adb.close();
      final commands = <String>[];
      final server = AdbServer(
        client: AdbClient(port: port),
        adbPath: r'C:\sPhone\scrcpy\adb.exe',
        launcher: (executable, arguments) async => commands.add('$executable ${arguments.join(' ')}'),
        startTimeout: const Duration(milliseconds: 600),
      );
      await expectLater(server.ensureRunning(), throwsA(isA<AdbException>()));
      expect(commands, [r'C:\sPhone\scrcpy\adb.exe start-server']);
      expect(server.startedByUs, isTrue);
    });

    test('signale un adb introuvable', () async {
      final port = adb.port;
      await adb.close();
      final server = AdbServer(client: AdbClient(port: port), adbPath: null);
      await expectLater(
        server.ensureRunning(),
        throwsA(isA<AdbException>().having((e) => e.message, 'message', contains('introuvable'))),
      );
    });
  });
}
