// Captures d'écran de la documentation (`docs/captures`). Elles ne sont produites que sur
// demande, pour ne pas réécrire des images à chaque exécution des tests :
//
//     SPHONE_CAPTURES=1 flutter test test/captures_test.dart

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sphone/models/phone.dart';
import 'package:sphone/state/phone_controller.dart';

import 'support/app_harness.dart';
import 'support/fake_process.dart';

const _window = Size(420, 860);

Future<void> capture(WidgetTester tester, String name) async {
  // Le logo de l'en-tête se charge en différé : on l'attend avant de capturer.
  final element = tester.element(find.byKey(captureKey));
  await tester.runAsync(() => precacheImage(const AssetImage('assets/branding/logo.png'), element));
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('docs/captures/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  final enabled = Platform.environment.containsKey('SPHONE_CAPTURES');
  setUpAll(loadFonts);

  testWidgets('accueil : téléphone branché', skip: !enabled, (tester) async {
    final controller = await pumpApp(tester, _window, prefs: {'theme': 'light'});
    show(controller, [usbLink]);
    await tester.pump(const Duration(milliseconds: 300));
    await capture(tester, 'accueil');
    await tearDownApp(tester, controller);
  });

  testWidgets('accueil sombre : écran affiché, Wi-Fi mémorisé', skip: !enabled, (tester) async {
    final launcher = FakeLauncher();
    final controller = await pumpApp(tester, _window, prefs: {'theme': 'dark'}, launcher: launcher);
    await controller.updateSettings(
      controller.settings.copyWith(
        wifi: const [WifiAddress(address: '192.168.1.20:5555', name: 'Galaxy S25', id: 'R5TEST')],
      ),
    );
    show(controller, [usbLink, wifiLink]);
    await tester.pump();
    await tester.tap(find.text('Afficher l\'écran'));
    await tester.pump(const Duration(milliseconds: 300));
    await capture(tester, 'accueil-sombre');
    await tearDownApp(tester, controller);
  });

  testWidgets('accueil : aucun téléphone', skip: !enabled, (tester) async {
    final controller = await pumpApp(tester, _window, prefs: {'theme': 'light'});
    await capture(tester, 'accueil-vide');
    await tearDownApp(tester, controller);
  });

  testWidgets('page Wi-Fi', skip: !enabled, (tester) async {
    final controller = await pumpApp(tester, _window, prefs: {'theme': 'light'});
    show(controller, [usbLink]);
    await tester.pump();
    await tester.tap(find.text('Connecter un téléphone en Wi-Fi'));
    await tester.pumpAndSettle();
    await capture(tester, 'wifi');
    await tearDownApp(tester, controller);
  });

  testWidgets('page Réglages', skip: !enabled, (tester) async {
    final controller = await pumpApp(tester, _window, prefs: {'theme': 'light', 'autoStart': true});
    await tester.tap(find.byTooltip('Réglages'));
    await tester.pumpAndSettle();
    await capture(tester, 'reglages');
    await tearDownApp(tester, controller);
  });

  testWidgets('page Mode d\'emploi', skip: !enabled, (tester) async {
    final controller = await pumpApp(tester, _window, prefs: {'theme': 'dark'});
    controller.debugSetState(service: ServiceState.ready);
    await tester.tap(find.byTooltip('Mode d\'emploi et raccourcis'));
    await tester.pumpAndSettle();
    await capture(tester, 'mode-d-emploi');
    await tearDownApp(tester, controller);
  });
}
