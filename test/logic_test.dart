import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sphone/data/adb/adb_parsers.dart';
import 'package:sphone/data/scrcpy.dart';
import 'package:sphone/data/settings.dart';
import 'package:sphone/data/tools.dart';
import 'package:sphone/models/phone.dart';

void main() {
  group('liste des liaisons adb', () {
    test('USB, Wi-Fi et autorisation en attente', () {
      final devices = parseDevices(
        'R5TEST                 device usb:1-2 product:pa1qxxx model:SM_S931B device:pa1q transport_id:3\n'
        '192.168.1.20:5555      device product:pa1qxxx model:SM_S931B device:pa1q transport_id:4\n'
        'R5AUTRE                unauthorized usb:1-3 transport_id:5\n'
        'adb-R5TLS-AbCdEf._adb-tls-connect._tcp\toffline transport_id:6\n',
      );
      expect(devices.map((d) => d.serial), [
        'R5TEST',
        '192.168.1.20:5555',
        'R5AUTRE',
        'adb-R5TLS-AbCdEf._adb-tls-connect._tcp',
      ]);
      expect(devices.map((d) => d.state), [
        LinkState.ready,
        LinkState.ready,
        LinkState.unauthorized,
        LinkState.offline,
      ]);
      expect(devices.map((d) => d.kind), [LinkKind.usb, LinkKind.wifi, LinkKind.usb, LinkKind.wifi]);
      expect(devices.first.model, 'SM-S931B');
      expect(devices[2].model, '');
    });

    test('liste vide', () {
      expect(parseDevices(''), isEmpty);
      expect(parseDevices('\n'), isEmpty);
    });

    test('un numéro de série USB n\'est pas pris pour une adresse', () {
      expect(isNetworkSerial('R5CX12345AB'), isFalse);
      expect(isNetworkSerial('emulator-5554'), isFalse);
      expect(isNetworkSerial('192.168.1.20:5555'), isTrue);
      expect(isNetworkSerial('galaxy.local:5555'), isTrue);
    });

    test('le câble est préféré au Wi-Fi pour afficher l\'écran', () {
      const wifi = AdbDevice(serial: '192.168.1.20:5555', state: LinkState.ready);
      const usb = AdbDevice(serial: 'R5TEST', state: LinkState.ready);
      const waiting = AdbDevice(serial: 'R5TEST', state: LinkState.unauthorized);
      expect(const Phone(id: 'x', name: 'S25', links: [wifi, usb]).bestLink, usb);
      expect(const Phone(id: 'x', name: 'S25', links: [wifi, waiting]).bestLink, wifi);
      expect(const Phone(id: 'x', name: 'S25', links: [waiting]).bestLink, isNull);
      expect(const Phone(id: 'x', name: 'S25', links: [waiting]).needsAuthorization, isTrue);
    });
  });

  group('téléphones annoncés sur le réseau', () {
    test('services de connexion et d\'association', () {
      final services = parseMdnsServices(
        'adb-R5TEST-AbCdEf\t_adb-tls-connect._tcp\t192.168.1.20:37251\n'
        'adb-R5TEST-AbCdEf\t_adb-tls-pairing._tcp.\t192.168.1.20:41873\n'
        'autre\t_adb._tcp\t192.168.1.30:5555\n'
        'ligne incomplète\n',
      );
      expect(services.length, 2);
      expect(services[0].pairing, isFalse);
      expect(services[0].address, '192.168.1.20:37251');
      expect(services[1].pairing, isTrue);
      expect(services[1].host, '192.168.1.20');
      expect(hardwareSerialFromMdnsName('adb-R5TEST-AbCdEf._adb-tls-connect._tcp'), 'R5TEST');
      expect(hardwareSerialFromMdnsName('192.168.1.20:5555'), isNull);
    });
  });

  group('adresse Wi-Fi du téléphone', () {
    test('lue dans « ip route », en ignorant le réseau mobile', () {
      const routes =
          '10.92.14.0/24 dev rmnet_data1 proto kernel scope link src 10.92.14.7\n'
          '192.168.1.0/24 dev wlan0 proto kernel scope link src 192.168.1.20\n';
      expect(parseWifiIp(routes), '192.168.1.20');
      expect(parseWifiIp('10.92.14.0/24 dev rmnet_data1 proto kernel scope link src 10.92.14.7\n'), isNull);
    });

    test('lue dans « ip addr »', () {
      const addr =
          '34: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500\n'
          '    inet 192.168.1.20/24 brd 192.168.1.255 scope global wlan0\n';
      expect(parseWifiIp(addr), '192.168.1.20');
      expect(parseWifiIp(''), isNull);
    });
  });

  group('saisie d\'une adresse', () {
    test('le port 5555 est ajouté s\'il manque', () {
      expect(normalizeAddress(' 192.168.1.20 '), '192.168.1.20:5555');
      expect(normalizeAddress('192.168.1.20:37123'), '192.168.1.20:37123');
      expect(normalizeAddress('galaxy.local'), 'galaxy.local:5555');
    });

    test('les saisies invalides sont refusées', () {
      for (final input in ['', '   ', '192.168.1.20:abc', '192.168.1.20:0', '192.168.1.20:70000', 'un deux', ':5555']) {
        expect(normalizeAddress(input), isNull, reason: input);
      }
    });
  });

  group('réponses d\'adb', () {
    test('connexion', () {
      expect(parseConnectReply('connected to 192.168.1.20:5555', '192.168.1.20:5555').ok, isTrue);
      expect(parseConnectReply('already connected to 192.168.1.20:5555', '192.168.1.20:5555').ok, isTrue);
      final refused = parseConnectReply(
        "failed to connect to '192.168.1.20:5555': Connection refused",
        '192.168.1.20:5555',
      );
      expect(refused.ok, isFalse);
      expect(refused.message, contains('refuse la connexion'));
      final windows = parseConnectReply('cannot connect to 192.168.1.20:5555: (10061)', '192.168.1.20:5555');
      expect(windows.message, contains('refuse la connexion'));
      final silent = parseConnectReply(
        "failed to connect to '192.168.1.20:5555': Connection timed out",
        '192.168.1.20:5555',
      );
      expect(silent.message, contains('Aucune réponse'));
    });

    test('association', () {
      expect(parsePairReply('Successfully paired to 192.168.1.20:41873 [guid=adb-R5TEST-AbCdEf]').ok, isTrue);
      final wrong = parsePairReply('Failed: Wrong password or connection was dropped.');
      expect(wrong.ok, isFalse);
      expect(wrong.message, contains('Code refusé'));
    });
  });

  group('arguments de scrcpy', () {
    test('réglages par défaut', () {
      final args = buildScrcpyArgs(
        serial: 'R5TEST',
        title: 'sPhone — Galaxy S25',
        settings: const Settings(),
        screenHeight: 1080,
      );
      expect(args, [
        '--serial=R5TEST',
        '--window-title=sPhone — Galaxy S25',
        '--video-bit-rate=8M',
        '--max-size=1600',
        '--max-fps=60',
        '--window-height=734',
        '--stay-awake',
      ]);
    });

    test('toutes les options', () {
      final args = buildScrcpyArgs(
        serial: '192.168.1.20:5555',
        title: 'sPhone',
        settings: const Settings(
          quality: Quality.sharp,
          fps: 120,
          windowSize: WindowSize.auto,
          keyboard: KeyboardMode.physical,
          audio: false,
          screenOff: true,
          stayAwake: false,
          lockOnClose: true,
          alwaysOnTop: true,
        ),
        screenHeight: 1440,
      );
      expect(args, [
        '--serial=192.168.1.20:5555',
        '--window-title=sPhone',
        '--video-bit-rate=16M',
        '--max-fps=120',
        '--always-on-top',
        '--no-audio',
        '--turn-screen-off',
        '--power-off-on-close',
        '--keyboard=uhid',
      ]);
    });

    test('sans hauteur d\'écran connue, scrcpy choisit la taille', () {
      final args = buildScrcpyArgs(serial: 'R5TEST', title: 'sPhone', settings: const Settings());
      expect(args.where((a) => a.startsWith('--window-height')), isEmpty);
    });

    test('scrcpy utilise l\'adb et les icônes de l\'application', () {
      const tools = Tools(
        adb: r'C:\sPhone\scrcpy\adb.exe',
        scrcpy: r'C:\sPhone\scrcpy\scrcpy.exe',
        iconDir: r'C:\sPhone\icones',
      );
      expect(scrcpyEnvironment(tools), {'ADB': r'C:\sPhone\scrcpy\adb.exe', 'SCRCPY_ICON_DIR': r'C:\sPhone\icones'});
    });

    test('un échec de démarrage est expliqué en français', () {
      expect(
        describeStartFailure([
          'INFO: scrcpy 5.0.1',
          'ERROR: Device is unauthorized:',
          'ERROR:     --> (usb) R5TEST unauthorized',
        ]),
        contains('Autoriser'),
      );
      expect(describeStartFailure(['ERROR: Could not find any ADB device']), contains('plus joignable'));
      expect(describeStartFailure(['ERROR: Server connection failed']), contains('Server connection failed'));
      expect(describeStartFailure([]), 'L\'affichage n\'a pas pu démarrer.');
    });
  });

  group('recherche des programmes', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('sphone_tools'));
    tearDown(() => temp.deleteSync(recursive: true));

    void touch(String path) => File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync('');

    test('le dossier « scrcpy » à côté de l\'application', () {
      touch(p.join(temp.path, 'scrcpy', 'scrcpy.exe'));
      touch(p.join(temp.path, 'scrcpy', 'adb.exe'));
      touch(p.join(temp.path, 'data', 'flutter_assets', 'assets', 'mirror', 'scrcpy.png'));
      final tools = Tools.locate(environment: const {}, executable: p.join(temp.path, 'sphone.exe'), windows: true);
      expect(tools.complete, isTrue);
      expect(tools.scrcpy, p.join(temp.path, 'scrcpy', 'scrcpy.exe'));
      expect(tools.adb, p.join(temp.path, 'scrcpy', 'adb.exe'));
      expect(tools.iconDir, p.join(temp.path, 'data', 'flutter_assets', 'assets', 'mirror'));
    });

    test('la variable SPHONE_SCRCPY_DIR passe avant, le PATH après', () {
      // Séparateur du PATH et extension des programmes : ceux du système qui exécute le test.
      final exe = Platform.isWindows ? '.exe' : '';
      final dev = p.join(temp.path, 'dev');
      final onPath = p.join(temp.path, 'bin');
      touch(p.join(dev, 'scrcpy$exe'));
      touch(p.join(onPath, 'scrcpy$exe'));
      touch(p.join(onPath, 'adb$exe'));
      final tools = Tools.locate(
        environment: {'SPHONE_SCRCPY_DIR': dev, 'PATH': onPath},
        executable: p.join(temp.path, 'app', 'sphone$exe'),
      );
      expect(tools.scrcpy, p.join(dev, 'scrcpy$exe'));
      expect(tools.adb, p.join(onPath, 'adb$exe'));
      expect(tools.iconDir, isNull);
    });

    test('programmes absents', () {
      final tools = Tools.locate(environment: const {}, executable: p.join(temp.path, 'sphone.exe'), windows: true);
      expect(tools.complete, isFalse);
    });
  });

  test('la version de scrcpy affichée est celle que la compilation télécharge', () {
    final pin = jsonDecode(File('tools/scrcpy.json').readAsStringSync()) as Map<String, dynamic>;
    expect(pin['version'], scrcpyVersion);
    expect(pin['url'], contains('v$scrcpyVersion/scrcpy-win64-v$scrcpyVersion.zip'));
    expect(pin['sha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
  });
}
