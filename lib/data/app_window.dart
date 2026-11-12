import 'dart:async';
import 'dart:ui';

import 'package:window_manager/window_manager.dart';

/// Ce que l'application demande à sa fenêtre.
abstract class AppWindow {
  /// Réduit sPhone dans la barre des tâches (pendant que le téléphone est affiché).
  Future<void> minimize();

  /// Fait réapparaître sPhone au premier plan.
  Future<void> restore();

  /// Hauteur de l'écran du PC, en pixels, si elle est connue.
  int? get screenHeight;
}

/// Sans fenêtre réelle : tests et aperçus.
class NoWindow implements AppWindow {
  const NoWindow();

  @override
  Future<void> minimize() async {}

  @override
  Future<void> restore() async {}

  @override
  int? get screenHeight => null;
}

/// La fenêtre Windows de l'application.
class DesktopWindow with WindowListener implements AppWindow {
  /// Appelé quand l'utilisateur ferme la fenêtre, avant sa destruction.
  Future<void> Function()? onClose;

  Future<void> init() async {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(360, 480));
    // La fermeture est interceptée pour arrêter proprement l'affichage et le service adb.
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
  }

  @override
  void onWindowClose() {
    unawaited(_close());
  }

  Future<void> _close() async {
    try {
      await onClose?.call().timeout(const Duration(seconds: 4));
    } on Object {
      // Rien ne doit empêcher la fermeture.
    } finally {
      await windowManager.destroy();
    }
  }

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> restore() async {
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  int? get screenHeight {
    final view = PlatformDispatcher.instance.implicitView;
    final height = (view?.display ?? PlatformDispatcher.instance.displays.firstOrNull)?.size.height;
    return height == null || height <= 0 ? null : height.round();
  }
}
