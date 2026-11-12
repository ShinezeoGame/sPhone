import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sphone/app.dart';
import 'package:sphone/data/adb/adb_client.dart';
import 'package:sphone/data/tools.dart';
import 'package:sphone/models/phone.dart';
import 'package:sphone/state/phone_controller.dart';

import 'fake_process.dart';

/// Client adb sans réseau : toute demande échoue aussitôt. Les tests d'affichage imposent
/// l'état de l'application au lieu de dialoguer avec un service.
class OfflineAdbClient extends AdbClient {
  @override
  Future<String> hostRequest(String service, {Duration timeout = const Duration(seconds: 10)}) async =>
      throw const AdbException('hors ligne');

  @override
  Future<Uint8List> run(String serial, String service, {Duration timeout = const Duration(seconds: 10)}) async =>
      throw const AdbException('hors ligne');

  @override
  Stream<String> track(String service) => Stream.error(const AdbException('hors ligne'));
}

/// Charge les vraies polices pour que les mesures de texte correspondent à l'application.
Future<void> loadFonts() async {
  final outfit = FontLoader('Outfit');
  for (final weight in ['300Light', '400Regular', '500Medium', '600SemiBold']) {
    final bytes = File('assets/fonts/Outfit_$weight.ttf').readAsBytesSync();
    outfit.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await outfit.load();

  // Les icônes Material viennent du SDK Flutter ; sans elles, des carrés les remplacent.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) return;
  final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (!icons.existsSync()) return;
  final material = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
  await material.load();
}

const usbLink = AdbDevice(serial: 'R5TEST', state: LinkState.ready, model: 'SM-S931B');
const wifiLink = AdbDevice(serial: '192.168.1.20:5555', state: LinkState.ready, model: 'SM-S931B');
const waitingLink = AdbDevice(serial: 'R5TEST', state: LinkState.unauthorized);

/// Clé de la zone capturée par [capture].
const captureKey = ValueKey('capture');

/// Affiche l'application dans une fenêtre de la taille donnée, sans service adb :
/// l'état est imposé avec [show].
Future<PhoneController> pumpApp(
  WidgetTester tester,
  Size size, {
  Map<String, Object> prefs = const {},
  Tools tools = const Tools(adb: 'adb', scrcpy: 'scrcpy'),
  FakeLauncher? launcher,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'autoStart': false, ...prefs});
  final controller = PhoneController(
    client: OfflineAdbClient(),
    tools: tools,
    launcher: (launcher ?? FakeLauncher()).call,
    minimizeDelay: Duration.zero,
  );
  await controller.loadSettings();
  controller.debugSetState(service: ServiceState.ready);
  await tester.pumpWidget(
    RepaintBoundary(
      key: captureKey,
      child: SPhoneApp(controller: controller),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return controller;
}

/// Impose les liaisons visibles (déjà identifiées : aucun appel à adb).
void show(PhoneController controller, List<AdbDevice> links, {String name = 'Galaxy S25'}) {
  for (final link in links) {
    if (link.ready) controller.setIdentity(link.serial, hardwareId: 'R5TEST', name: name);
  }
  controller.applyDevices(links);
}

Future<void> tearDownApp(WidgetTester tester, PhoneController controller) async {
  await tester.pumpWidget(const SizedBox());
  controller.dispose();
  await tester.pump(const Duration(seconds: 5));
}
