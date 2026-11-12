import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sphone/data/settings.dart';
import 'package:sphone/data/tools.dart';
import 'package:sphone/models/phone.dart';
import 'package:sphone/state/phone_controller.dart';
import 'package:sphone/ui/pages/help_page.dart';
import 'package:sphone/ui/pages/settings_page.dart';
import 'package:sphone/ui/pages/wifi_page.dart';
import 'package:sphone/ui/widgets/controls.dart';

import 'support/app_harness.dart';
import 'support/fake_process.dart';

void main() {
  setUpAll(loadFonts);

  const sizes = {
    'fenêtre minimale 360×480': Size(360, 480),
    'fenêtre par défaut 420×860': Size(420, 860),
    'fenêtre agrandie 1100×700': Size(1100, 700),
  };

  /// Fait défiler la page jusqu'en bas : tout le contenu est construit et mesuré.
  Future<void> scrollThrough(WidgetTester tester) async {
    final list = find.byType(Scrollable).first;
    for (var i = 0; i < 12; i++) {
      await tester.drag(list, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
  }

  /// Amène à l'écran un élément situé plus bas dans la page (la liste est construite à la demande).
  Future<void> reveal(WidgetTester tester, Finder finder, {bool upwards = false}) async {
    await tester.scrollUntilVisible(finder, upwards ? -120 : 120, scrollable: find.byType(Scrollable).first);
    await tester.pump(const Duration(milliseconds: 100));
  }

  for (final MapEntry(key: label, value: size) in sizes.entries) {
    group(label, () {
      for (final dark in [false, true]) {
        final theme = dark ? 'sombre' : 'clair';

        testWidgets('accueil dans tous ses états ($theme)', (tester) async {
          final controller = await pumpApp(tester, size, prefs: {'theme': dark ? 'dark' : 'light'});
          expect(find.text('Aucun téléphone détecté'), findsOneWidget);
          expect(tester.takeException(), isNull);

          controller.debugSetState(service: ServiceState.starting);
          await tester.pump();
          expect(find.text('Recherche des téléphones…'), findsOneWidget);

          controller.debugSetState(service: ServiceState.failed, serviceError: 'Le service adb ne démarre pas.');
          await tester.pump();
          expect(find.textContaining('Nouvel essai'), findsOneWidget);

          controller.debugSetState(service: ServiceState.ready);
          show(controller, [waitingLink]);
          await tester.pump();
          expect(find.text('En attente de votre autorisation'), findsOneWidget);

          show(controller, [usbLink]);
          await tester.pump();
          expect(find.text('Galaxy S25'), findsOneWidget);
          expect(find.text('Branché en USB'), findsOneWidget);
          expect(find.text('Afficher l\'écran'), findsOneWidget);
          expect(find.text('Passer en Wi-Fi'), findsOneWidget);

          show(controller, [usbLink, wifiLink], name: 'Galaxy S25 Ultra de Marie-Christine');
          await tester.pump();
          expect(find.text('Branché en USB · Wi-Fi actif'), findsOneWidget);
          expect(find.text('Passer en Wi-Fi'), findsNothing);

          await controller.updateSettings(
            controller.settings.copyWith(
              wifi: const [
                WifiAddress(address: '192.168.1.20:5555', name: 'Galaxy S25', id: 'R5TEST'),
                WifiAddress(address: 'telephone-du-salon.maison.example:5555'),
              ],
            ),
          );
          controller.debugSetState(
            notice: const Notice(
              'La liaison avec Galaxy S25 a été interrompue. Vérifiez le câble ou le Wi-Fi.',
              error: true,
            ),
          );
          await tester.pump();
          expect(find.textContaining('interrompue'), findsOneWidget);
          await scrollThrough(tester);
          await tearDownApp(tester, controller);
        });
      }

      testWidgets('écran affiché : la tuile propose d\'arrêter', (tester) async {
        final launcher = FakeLauncher();
        final controller = await pumpApp(tester, size, launcher: launcher);
        show(controller, [usbLink]);
        await tester.pump();

        await tester.tap(find.text('Afficher l\'écran'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(launcher.started.single.arguments, contains('--serial=R5TEST'));
        expect(find.text('Écran affiché · USB'), findsOneWidget);
        expect(find.text('Arrêter l\'affichage'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Arrêter l\'affichage'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 2));
        expect(launcher.started.single.killed, isTrue);
        expect(find.text('Afficher l\'écran'), findsOneWidget);
        await tearDownApp(tester, controller);
      });

      testWidgets('programmes absents : le message l\'explique', (tester) async {
        final controller = await pumpApp(tester, size, tools: const Tools());
        expect(find.textContaining('introuvables'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tearDownApp(tester, controller);
      });

      testWidgets('page Wi-Fi', (tester) async {
        final controller = await pumpApp(tester, size);
        await tester.tap(find.text('Connecter un téléphone en Wi-Fi'));
        await tester.pumpAndSettle();
        expect(find.byType(WifiPage), findsOneWidget);
        expect(find.text('Aucun téléphone branché en USB'), findsOneWidget);
        expect(tester.takeException(), isNull);

        show(controller, [usbLink]);
        await tester.pump();
        expect(find.text('Activer le Wi-Fi sur Galaxy S25'), findsOneWidget);

        // Saisie invalide : l'erreur s'affiche sur la page.
        await reveal(tester, find.widgetWithText(AppButton, 'Connecter'));
        await tester.enterText(find.widgetWithText(TextField, 'Adresse IP'), 'pas une adresse');
        await tester.tap(find.widgetWithText(AppButton, 'Connecter'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.notice!.message, contains('Adresse invalide'));
        await reveal(tester, find.textContaining('Adresse invalide'), upwards: true);
        expect(find.textContaining('Adresse invalide'), findsOneWidget);
        await scrollThrough(tester);

        await tester.tap(find.byTooltip('Retour'));
        await tester.pumpAndSettle();
        expect(find.byType(WifiPage), findsNothing);
        await tearDownApp(tester, controller);
      });

      testWidgets('page Réglages : chaque choix est enregistré', (tester) async {
        final controller = await pumpApp(tester, size);
        await tester.tap(find.byTooltip('Réglages'));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(tester.takeException(), isNull);

        await reveal(tester, find.text('Fluide'));
        await tester.tap(find.text('Fluide'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(controller.settings.quality, Quality.smooth);

        await reveal(tester, find.text('Clavier physique'));
        await tester.tap(find.text('Clavier physique'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(controller.settings.keyboard, KeyboardMode.physical);
        expect(find.text('Régler la disposition sur le téléphone'), findsOneWidget);

        await reveal(tester, find.text('Sombre'));
        await tester.tap(find.text('Sombre'));
        await tester.pumpAndSettle();
        expect(controller.settings.theme, AppThemeMode.dark);
        expect(Theme.of(tester.element(find.byType(SettingsPage))).brightness, Brightness.dark);

        expect((await SettingsStore().load()).quality, Quality.smooth);
        await scrollThrough(tester);
        await tearDownApp(tester, controller);
      });

      testWidgets('page Mode d\'emploi', (tester) async {
        final controller = await pumpApp(tester, size);
        await tester.tap(find.byTooltip('Mode d\'emploi et raccourcis'));
        await tester.pumpAndSettle();
        expect(find.byType(HelpPage), findsOneWidget);
        expect(find.text('Première connexion'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await scrollThrough(tester);
        await tearDownApp(tester, controller);
      });
    });
  }
}
