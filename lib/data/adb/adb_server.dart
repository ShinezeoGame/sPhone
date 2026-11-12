import 'dart:async';
import 'dart:io';

import 'adb_client.dart';

/// Lance un programme sans attendre sa fin (remplaçable dans les tests).
typedef DetachedLauncher = Future<void> Function(String executable, List<String> arguments);

/// Démarre et arrête le service adb fourni avec l'application.
class AdbServer {
  AdbServer({
    required this.client,
    required this.adbPath,
    DetachedLauncher? launcher,
    this.startTimeout = const Duration(seconds: 15),
  }) : _launcher = launcher ?? _launchDetached;

  final AdbClient client;

  /// Chemin de `adb.exe`, ou `null` s'il est introuvable.
  final String? adbPath;
  final Duration startTimeout;
  final DetachedLauncher _launcher;

  /// Vrai si c'est l'application qui a démarré le service : elle l'arrêtera en quittant.
  bool startedByUs = false;

  /// S'assure que le service répond, en le démarrant si besoin.
  Future<void> ensureRunning() async {
    if (await client.isAlive()) return;
    final adb = adbPath;
    if (adb == null) {
      throw const AdbException('Le programme adb est introuvable : réinstallez sPhone.');
    }
    try {
      // Lancement détaché : `adb start-server` laisse un service en arrière-plan qui
      // hériterait sinon des tuyaux de sortie, et l'attente de sa fin ne rendrait jamais la main.
      await _launcher(adb, const ['start-server']);
    } on Object catch (error) {
      throw AdbException('Impossible de lancer adb : $error');
    }
    startedByUs = true;
    final deadline = DateTime.now().add(startTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await client.isAlive()) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw const AdbException(
      'Le service adb ne démarre pas. Un antivirus ou un autre programme bloque peut-être le port 5037.',
    );
  }

  /// Arrête le service si l'application l'a démarré (sinon un autre outil s'en sert).
  Future<void> stopIfOwned() async {
    if (!startedByUs) return;
    startedByUs = false;
    await client.kill();
  }

  static Future<void> _launchDetached(String executable, List<String> arguments) async {
    await Process.start(executable, arguments, mode: ProcessStartMode.detached);
  }
}
