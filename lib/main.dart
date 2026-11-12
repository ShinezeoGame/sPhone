import 'package:flutter/material.dart';

import 'app.dart';
import 'data/app_window.dart';
import 'state/phone_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final window = DesktopWindow();
  await window.init();
  final controller = PhoneController(window: window);
  // À la fermeture : la fenêtre du téléphone se ferme et le service adb s'arrête.
  window.onClose = controller.shutdown;
  // Les réglages sont lus avant le premier affichage : le thème choisi s'applique d'emblée.
  await controller.loadSettings();
  runApp(SPhoneApp(controller: controller));
  controller.start();
}
