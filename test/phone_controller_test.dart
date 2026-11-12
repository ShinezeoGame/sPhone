import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sphone/data/adb/adb_client.dart';
import 'package:sphone/data/adb/adb_server.dart';
import 'package:sphone/data/settings.dart';
import 'package:sphone/data/tools.dart';
import 'package:sphone/models/phone.dart';
import 'package:sphone/state/phone_controller.dart';

import 'support/fake_adb.dart';
import 'support/fake_process.dart';

const _usbLine = 'R5TEST                 device usb:1-2 product:pa1qxxx model:SM_S931B device:pa1q transport_id:1\n';
const _wifiLine = '192.168.1.20:5555      device product:pa1qxxx model:SM_S931B device:pa1q transport_id:2\n';
const _tools = Tools(adb: '/outils/adb', scrcpy: '/outils/scrcpy', iconDir: '/outils/icones');

/// Attend qu'une condition devienne vraie (les échanges avec le faux adb sont asynchrones).
Future<void> until(bool Function() condition, {String? reason}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Condition jamais remplie${reason == null ? '' : ' : $reason'}');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late FakeAdb adb;
  late FakeLauncher launcher;
  late PhoneController controller;
  late Directory temp;

  Future<PhoneController> create({Map<String, Object> prefs = const {}, Tools tools = _tools}) async {
    SharedPreferences.setMockInitialValues(prefs);
    final client = AdbClient(port: adb.port);
    final c = PhoneController(
      client: client,
      tools: tools,
      server: AdbServer(
        client: client,
        adbPath: tools.adb,
        launcher: (_, _) async {},
        startTimeout: const Duration(milliseconds: 300),
      ),
      launcher: launcher.call,
      screenshotDirectory: () => temp,
      retryDelay: const Duration(milliseconds: 50),
      wifiRetryDelay: const Duration(milliseconds: 20),
      minimizeDelay: const Duration(milliseconds: 20),
    );
    await c.loadSettings();
    return c;
  }

  setUp(() async {
    adb = await FakeAdb.start();
    adb.shell['getprop ro.serialno'] = 'R5TEST\nGalaxy S25\n';
    launcher = FakeLauncher();
    temp = Directory.systemTemp.createTempSync('sphone_test');
  });

  tearDown(() async {
    await controller.shutdown();
    controller.dispose();
    await adb.close();
    temp.deleteSync(recursive: true);
  });

  group('téléphones', () {
    test('un téléphone branché apparaît avec le nom choisi par son propriétaire', () async {
      controller = await create(prefs: {'autoStart': false});
      controller.start();
      await until(() => controller.service == ServiceState.ready);
      expect(controller.phones, isEmpty);

      adb.setDevices(_usbLine);
      await until(() => controller.phones.isNotEmpty && controller.phones.first.name == 'Galaxy S25');
      final phone = controller.phones.single;
      expect(phone.id, 'R5TEST');
      expect(phone.hasUsb, isTrue);
      expect(phone.hasWifi, isFalse);

      adb.setDevices('');
      await until(() => controller.phones.isEmpty);
    });

    test('les liaisons USB et Wi-Fi d\'un même téléphone sont réunies', () async {
      controller = await create(prefs: {'autoStart': false});
      controller.start();
      adb.setDevices(_usbLine + _wifiLine);
      await until(() => controller.phones.length == 1 && controller.phones.single.links.length == 2);
      final phone = controller.phones.single;
      expect(phone.hasUsb && phone.hasWifi, isTrue);
      expect(phone.bestLink!.serial, 'R5TEST');
    });

    test('un téléphone non autorisé est signalé, sans être interrogé', () async {
      controller = await create();
      controller.start();
      adb.setDevices('R5TEST                 unauthorized usb:1-2 transport_id:1\n');
      await until(() => controller.phones.isNotEmpty);
      expect(controller.phones.single.needsAuthorization, isTrue);
      expect(controller.phones.single.ready, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(launcher.started, isEmpty);
      expect(adb.requests.where((r) => r.startsWith('shell:')), isEmpty);
    });

    test('le suivi reprend quand le service adb redémarre', () async {
      controller = await create(prefs: {'autoStart': false});
      controller.start();
      adb.setDevices(_usbLine);
      await until(() => controller.phones.isNotEmpty);
      final port = adb.port;
      await adb.close();
      await until(() => controller.phones.isEmpty && controller.service != ServiceState.ready);
      // Le « service » revient sur le même port : l'application s'y rattache d'elle-même.
      adb = await FakeAdb.startOn(port);
      adb.shell['getprop ro.serialno'] = 'R5TEST\nGalaxy S25\n';
      adb.setDevices(_usbLine);
      await until(() => controller.service == ServiceState.ready && controller.phones.isNotEmpty);
    });

    test('adb introuvable : l\'erreur est affichée', () async {
      final port = adb.port;
      await adb.close();
      SharedPreferences.setMockInitialValues({});
      final client = AdbClient(port: port);
      controller = PhoneController(
        client: client,
        tools: const Tools(),
        launcher: launcher.call,
        retryDelay: const Duration(milliseconds: 50),
      );
      controller.start();
      await until(() => controller.service == ServiceState.failed);
      expect(controller.serviceError, contains('introuvable'));
      adb = await FakeAdb.start();
    });
  });

  group('affichage', () {
    test('s\'ouvre dès la connexion, avec le bon téléphone, le bon titre et le bon adb', () async {
      controller = await create();
      controller.start();
      adb.setDevices(_usbLine);
      await until(() => launcher.started.isNotEmpty);
      final process = launcher.last;
      expect(process.executable, '/outils/scrcpy');
      expect(process.arguments, containsAll(['--serial=R5TEST', '--window-title=sPhone — Galaxy S25', '--max-fps=60']));
      expect(process.environment, {'ADB': '/outils/adb', 'SCRCPY_ICON_DIR': '/outils/icones'});
      expect(controller.isMirroring(controller.phones.single), isTrue);
      expect(controller.session!.kind, LinkKind.usb);
    });

    test('une fenêtre fermée par l\'utilisateur ne se rouvre pas toute seule', () async {
      controller = await create();
      controller.start();
      adb.setDevices(_usbLine);
      await until(() => launcher.started.isNotEmpty);
      launcher.last.finish(0);
      await until(() => controller.session == null);
      expect(controller.notice, isNull);
      // Un changement sans rapport (le Wi-Fi s'ajoute) ne relance pas l'affichage.
      adb.setDevices(_usbLine + _wifiLine);
      await until(() => controller.phones.single.links.length == 2);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(launcher.started.length, 1);

      // Débranché puis rebranché : l'affichage repart.
      adb.setDevices('');
      await until(() => controller.phones.isEmpty);
      adb.setDevices(_usbLine);
      await until(() => launcher.started.length == 2);
    });

    test('réglage « Afficher dès la connexion » désactivé : rien ne se lance', () async {
      controller = await create(prefs: {'autoStart': false});
      controller.start();
      adb.setDevices(_usbLine);
      await until(() => controller.phones.isNotEmpty && controller.phones.first.name == 'Galaxy S25');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(launcher.started, isEmpty);

      await controller.startMirror(controller.phones.single);
      expect(launcher.started.length, 1);
      await controller.stopMirror();
      await until(() => controller.session == null);
      expect(launcher.last.killed, isTrue);
    });

    test('un échec au démarrage est expliqué et ne boucle pas', () async {
      controller = await create();
      controller.start();
      adb.setDevices(_usbLine);
      await until(() => launcher.started.isNotEmpty);
      launcher.last.finish(1, stderr: 'ERROR: Device is unauthorized:\nERROR:     --> (usb) R5TEST unauthorized\n');
      await until(() => controller.notice != null);
      expect(controller.notice!.error, isTrue);
      expect(controller.notice!.message, contains('Autoriser'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(launcher.started.length, 1);
    });

    test('une liaison coupée aussitôt établie ne relance pas l\'affichage en boucle', () async {
      controller = await create();
      controller.start();
      adb.setDevices(_usbLine);
      await until(() => launcher.started.isNotEmpty);
      launcher.last.finish(2);
      await until(() => controller.notice != null);
      expect(controller.notice!.message, contains('interrompue'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(launcher.started.length, 1);
    });

    test('les réglages choisis sont transmis à scrcpy', () async {
      controller = await create(
        prefs: {'autoStart': false, 'quality': 'smooth', 'fps': 30, 'audio': false, 'keyboard': 'physical'},
      );
      controller.start();
      adb.setDevices(_wifiLine);
      await until(() => controller.phones.isNotEmpty && controller.phones.first.name == 'Galaxy S25');
      await controller.startMirror(controller.phones.single);
      expect(
        launcher.last.arguments,
        containsAll([
          '--serial=192.168.1.20:5555',
          '--video-bit-rate=4M',
          '--max-size=1024',
          '--max-fps=30',
          '--no-audio',
          '--keyboard=uhid',
        ]),
      );
      expect(controller.session!.kind, LinkKind.wifi);
    });
  });

  group('Wi-Fi', () {
    test('« Passer en Wi-Fi » : trouve l\'adresse, active l\'écoute, se connecte et mémorise', () async {
      controller = await create(prefs: {'autoStart': false});
      controller.start();
      adb.shell['ip route'] = '192.168.1.0/24 dev wlan0 proto kernel scope link src 192.168.1.20\n';
      var listening = false;
      adb.onTcpip = () => listening = true;
      adb.onConnect = (address) {
        if (!listening) return "failed to connect to '$address': Connection refused";
        adb.setDevices(_usbLine + _wifiLine);
        return 'connected to $address';
      };
      adb.setDevices(_usbLine);
      await until(() => controller.phones.isNotEmpty && controller.phones.first.name == 'Galaxy S25');

      expect(await controller.enableWifi(controller.phones.single), isTrue);
      expect(adb.requests, containsAllInOrder(['shell:ip route', 'tcpip:5555', 'host:connect:192.168.1.20:5555']));
      expect(controller.notice!.error, isFalse);
      expect(controller.notice!.message, contains('débrancher'));
      final saved = controller.settings.wifi.single;
      expect((saved.address, saved.name, saved.id), ('192.168.1.20:5555', 'Galaxy S25', 'R5TEST'));
      await until(() => controller.phones.single.hasWifi);

      // Mémorisé sur le disque : retrouvé au prochain lancement.
      expect((await SettingsStore().load()).wifi.single.address, '192.168.1.20:5555');
    });

    test('« Passer en Wi-Fi » sans réseau Wi-Fi sur le téléphone', () async {
      controller = await create(prefs: {'autoStart': false});
      controller.start();
      adb.shell['ip route'] = '10.92.14.0/24 dev rmnet_data1 proto kernel scope link src 10.92.14.7\n';
      adb.setDevices(_usbLine);
      await until(() => controller.phones.isNotEmpty);
      expect(await controller.enableWifi(controller.phones.single), isFalse);
      expect(controller.notice!.message, contains('aucun réseau Wi-Fi'));
      expect(adb.requests, isNot(contains('tcpip:5555')));
    });

    test('connexion par adresse : saisie invalide, refus, réussite', () async {
      controller = await create(prefs: {'autoStart': false});
      controller.start();
      await until(() => controller.service == ServiceState.ready);

      expect(await controller.connectAddress('pas une adresse'), isFalse);
      expect(controller.notice!.message, contains('Adresse invalide'));

      adb.onConnect = (address) => "failed to connect to '$address': Connection refused";
      expect(await controller.connectAddress('192.168.1.20'), isFalse);
      expect(controller.notice!.message, contains('refuse la connexion'));
      expect(controller.settings.wifi, isEmpty);

      adb.onConnect = (address) => 'connected to $address';
      expect(await controller.connectAddress('192.168.1.20'), isTrue);
      expect(controller.settings.wifi.single.address, '192.168.1.20:5555');
    });

    test('les adresses mémorisées sont rappelées au démarrage, puis oubliées sur demande', () async {
      controller = await create(
        prefs: {'autoStart': false, 'wifi': '[{"address":"192.168.1.20:5555","name":"Galaxy S25","id":"R5TEST"}]'},
      );
      adb.onConnect = (address) {
        adb.setDevices(_wifiLine);
        return 'connected to $address';
      };
      controller.start();
      await until(() => controller.phones.isNotEmpty);
      expect(adb.requests, contains('host:connect:192.168.1.20:5555'));
      final saved = controller.settings.wifi.single;
      expect(controller.isConnected(saved), isTrue);

      await controller.forgetWifi(saved);
      expect(controller.settings.wifi, isEmpty);
      expect(adb.requests, contains('host:disconnect:192.168.1.20:5555'));
    });

    test('association par code : contrôles de saisie puis demande à adb', () async {
      controller = await create(prefs: {'autoStart': false});
      controller.start();
      await until(() => controller.service == ServiceState.ready);

      expect(await controller.pair('192.168.1.20', '123456'), isFalse, reason: 'le port est obligatoire');
      expect(await controller.pair('192.168.1.20:41873', '12345'), isFalse);
      expect(controller.notice!.message, contains('six chiffres'));
      expect(adb.requests.where((r) => r.startsWith('host:pair')), isEmpty);

      adb.onPair = (code, address) => 'Failed: Wrong password or connection was dropped.';
      expect(await controller.pair('192.168.1.20:41873', '123456'), isFalse);
      expect(controller.notice!.message, contains('Code refusé'));

      adb.onPair = (code, address) => 'Successfully paired to $address [guid=adb-R5TEST-AbCdEf]';
      adb.mdns = 'adb-R5TEST-AbCdEf\t_adb-tls-connect._tcp\t192.168.1.20:37251\n';
      expect(await controller.pair('192.168.1.20:41873', '123 456'), isTrue);
      expect(
        adb.requests,
        containsAllInOrder(['host:pair:123456:192.168.1.20:41873', 'host:connect:192.168.1.20:37251']),
      );
    });

    test('les téléphones annoncés sur le réseau sont listés', () async {
      controller = await create(prefs: {'autoStart': false});
      controller.start();
      await until(() => controller.service == ServiceState.ready);
      adb.mdns =
          'adb-R5TEST-AbCdEf\t_adb-tls-pairing._tcp\t192.168.1.20:41873\n'
          'adb-R5TEST-AbCdEf\t_adb-tls-connect._tcp\t192.168.1.20:37251\n';
      await controller.refreshNearby();
      expect(controller.nearby.map((s) => (s.address, s.pairing)), [
        ('192.168.1.20:41873', true),
        ('192.168.1.20:37251', false),
      ]);
    });
  });

  test('la capture d\'écran est enregistrée en PNG dans le dossier des images', () async {
    controller = await create(prefs: {'autoStart': false});
    controller.start();
    adb.exec = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3]);
    adb.setDevices(_usbLine);
    await until(() => controller.phones.isNotEmpty);

    final path = await controller.takeScreenshot(controller.phones.single);
    expect(path, isNotNull);
    expect(RegExp(r'sPhone_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.png$').hasMatch(path!), isTrue);
    expect(File(path).readAsBytesSync().length, 11);
    expect(adb.requests, contains('exec:screencap -p'));

    adb.exec = Uint8List.fromList([1, 2, 3]);
    expect(await controller.takeScreenshot(controller.phones.single), isNull);
    expect(controller.notice!.error, isTrue);
  });
}
