import 'dart:io';

import 'package:path/path.dart' as p;

/// Emplacement des programmes dont l'application se sert : `scrcpy` (affichage et
/// contrôle du téléphone) et `adb` (liaison avec le téléphone).
class Tools {
  const Tools({this.adb, this.scrcpy, this.iconDir});

  final String? adb;
  final String? scrcpy;

  /// Dossier des icônes de la fenêtre d'affichage (`scrcpy.png`, `disconnected.png`).
  final String? iconDir;

  bool get complete => adb != null && scrcpy != null;

  /// Cherche les programmes, dans l'ordre :
  ///  1. le dossier donné par la variable d'environnement `SPHONE_SCRCPY_DIR` (développement) ;
  ///  2. le dossier `scrcpy` placé à côté de l'application (cas normal : la version installée) ;
  ///  3. les dossiers du `PATH`.
  static Tools locate({Map<String, String>? environment, String? executable, bool? windows}) {
    final env = environment ?? Platform.environment;
    final isWindows = windows ?? Platform.isWindows;
    final appDir = p.dirname(executable ?? Platform.resolvedExecutable);
    final suffix = isWindows ? '.exe' : '';

    final folders = <String>[
      if ((env['SPHONE_SCRCPY_DIR'] ?? '').isNotEmpty) env['SPHONE_SCRCPY_DIR']!,
      p.join(appDir, 'scrcpy'),
      ...(env['PATH'] ?? env['Path'] ?? '').split(isWindows ? ';' : ':').where((f) => f.isNotEmpty),
    ];

    String? find(String name) {
      for (final folder in folders) {
        final candidate = p.join(folder, '$name$suffix');
        if (File(candidate).existsSync()) return candidate;
      }
      return null;
    }

    final icons = p.join(appDir, 'data', 'flutter_assets', 'assets', 'mirror');
    return Tools(
      adb: find('adb'),
      scrcpy: find('scrcpy'),
      iconDir: File(p.join(icons, 'scrcpy.png')).existsSync() ? icons : null,
    );
  }
}
