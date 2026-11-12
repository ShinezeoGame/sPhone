import 'dart:io';

import 'package:path/path.dart' as p;

import 'settings.dart';
import 'tools.dart';

/// Version de scrcpy fournie avec l'application (téléchargée et vérifiée à la compilation :
/// voir `tools/scrcpy.json`).
const scrcpyVersion = '5.0.1';

/// Lance un programme (remplaçable dans les tests).
typedef ProcessLauncher = Future<Process> Function(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
  String? workingDirectory,
});

/// Arguments de scrcpy pour afficher le téléphone [serial] avec les réglages donnés.
///
/// [screenHeight] est la hauteur de l'écran du PC en pixels : elle sert à donner à la
/// fenêtre une hauteur proportionnée, quelle que soit la définition de l'écran.
List<String> buildScrcpyArgs({
  required String serial,
  required String title,
  required Settings settings,
  int? screenHeight,
}) {
  final quality = settings.quality;
  final fraction = settings.windowSize.fraction;
  return [
    '--serial=$serial',
    '--window-title=$title',
    '--video-bit-rate=${quality.megabits}M',
    if (quality.maxSize > 0) '--max-size=${quality.maxSize}',
    '--max-fps=${settings.fps}',
    if (fraction > 0 && screenHeight != null && screenHeight >= 480)
      '--window-height=${(screenHeight * fraction).round()}',
    if (settings.alwaysOnTop) '--always-on-top',
    if (!settings.audio) '--no-audio',
    if (settings.screenOff) '--turn-screen-off',
    if (settings.stayAwake) '--stay-awake',
    if (settings.lockOnClose) '--power-off-on-close',
    if (settings.keyboard == KeyboardMode.physical) '--keyboard=uhid',
  ];
}

/// Variables d'environnement de scrcpy : il doit se servir du même adb que l'application
/// (deux versions différentes se couperaient la liaison l'une l'autre), et de ses icônes.
Map<String, String> scrcpyEnvironment(Tools tools) => {
  if (tools.adb != null) 'ADB': tools.adb!,
  if (tools.iconDir != null) 'SCRCPY_ICON_DIR': tools.iconDir!,
};

Future<Process> startScrcpy(Tools tools, List<String> arguments, {ProcessLauncher launcher = Process.start}) {
  final executable = tools.scrcpy!;
  return launcher(
    executable,
    arguments,
    environment: scrcpyEnvironment(tools),
    workingDirectory: p.dirname(executable),
  );
}

/// Codes de fin de scrcpy.
abstract final class ScrcpyExit {
  /// Fenêtre fermée par l'utilisateur.
  static const closed = 0;

  /// L'affichage n'a pas pu démarrer.
  static const startFailure = 1;

  /// Le téléphone a été débranché ou la liaison coupée.
  static const disconnected = 2;
}

/// Explique en français pourquoi l'affichage n'a pas démarré, à partir des dernières
/// lignes écrites par scrcpy.
String describeStartFailure(List<String> log) {
  final errors = [
    for (final line in log)
      if (line.startsWith('ERROR:')) line.substring(6).trim(),
  ];
  final all = errors.join('\n').toLowerCase();
  if (all.contains('unauthorized')) {
    return 'Le téléphone attend votre autorisation : déverrouillez-le et touchez « Autoriser » dans la fenêtre '
        '« Autoriser le débogage USB ».';
  }
  if (all.contains('could not find') && all.contains('adb device')) {
    return 'Le téléphone n\'est plus joignable. Vérifiez le câble ou la connexion Wi-Fi.';
  }
  if (all.contains('inject_events')) {
    return 'Le téléphone refuse d\'être contrôlé depuis le PC. Vérifiez les options de développement.';
  }
  if (errors.isEmpty) return 'L\'affichage n\'a pas pu démarrer.';
  return 'L\'affichage n\'a pas pu démarrer : ${errors.first}';
}
