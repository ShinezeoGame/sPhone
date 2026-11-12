import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/phone.dart';

/// Thème de l'interface : automatique (suit le réglage de Windows), clair ou sombre.
enum AppThemeMode { auto, light, dark }

/// Compromis entre netteté de l'image et fluidité.
enum Quality {
  /// Image allégée : pour un Wi-Fi capricieux ou un PC modeste.
  smooth(maxSize: 1024, megabits: 4),

  /// Bon équilibre, convient à presque tout.
  balanced(maxSize: 1600, megabits: 8),

  /// Définition native du téléphone.
  sharp(maxSize: 0, megabits: 16);

  const Quality({required this.maxSize, required this.megabits});

  /// Plus grand côté de l'image, en pixels (0 : pas de limite).
  final int maxSize;

  /// Débit vidéo, en Mbit/s.
  final int megabits;
}

/// Hauteur de la fenêtre du téléphone, en proportion de la hauteur de l'écran du PC.
enum WindowSize {
  compact(0.5),
  medium(0.68),
  large(0.86),

  /// Laisse scrcpy choisir : aussi grand que l'écran le permet.
  auto(0);

  const WindowSize(this.fraction);

  final double fraction;
}

enum KeyboardMode {
  /// Saisie de texte injectée : fonctionne sans réglage.
  simple,

  /// Le PC se présente comme un clavier physique branché au téléphone : toutes les
  /// touches et tous les raccourcis passent, mais la disposition (AZERTY) se règle
  /// une fois sur le téléphone.
  physical,
}

class Settings {
  const Settings({
    this.theme = AppThemeMode.auto,
    this.quality = Quality.balanced,
    this.fps = 60,
    this.windowSize = WindowSize.medium,
    this.keyboard = KeyboardMode.simple,
    this.audio = true,
    this.screenOff = false,
    this.stayAwake = true,
    this.lockOnClose = false,
    this.alwaysOnTop = false,
    this.autoStart = true,
    this.minimize = true,
    this.wifi = const [],
  });

  final AppThemeMode theme;
  final Quality quality;

  /// Images par seconde au maximum : 30, 60 ou 120.
  final int fps;
  final WindowSize windowSize;
  final KeyboardMode keyboard;

  /// Jouer le son du téléphone sur le PC.
  final bool audio;

  /// Éteindre l'écran du téléphone pendant qu'il est affiché sur le PC.
  final bool screenOff;

  /// Empêcher le téléphone de se mettre en veille tant qu'il est branché.
  final bool stayAwake;

  /// Verrouiller le téléphone à la fermeture de la fenêtre.
  final bool lockOnClose;

  /// Garder la fenêtre du téléphone au-dessus des autres.
  final bool alwaysOnTop;

  /// Afficher l'écran dès qu'un téléphone est connecté.
  final bool autoStart;

  /// Réduire sPhone dans la barre des tâches pendant l'affichage.
  final bool minimize;

  /// Téléphones déjà reliés en Wi-Fi.
  final List<WifiAddress> wifi;

  static const fpsChoices = [30, 60, 120];

  Settings copyWith({
    AppThemeMode? theme,
    Quality? quality,
    int? fps,
    WindowSize? windowSize,
    KeyboardMode? keyboard,
    bool? audio,
    bool? screenOff,
    bool? stayAwake,
    bool? lockOnClose,
    bool? alwaysOnTop,
    bool? autoStart,
    bool? minimize,
    List<WifiAddress>? wifi,
  }) => Settings(
    theme: theme ?? this.theme,
    quality: quality ?? this.quality,
    fps: fps ?? this.fps,
    windowSize: windowSize ?? this.windowSize,
    keyboard: keyboard ?? this.keyboard,
    audio: audio ?? this.audio,
    screenOff: screenOff ?? this.screenOff,
    stayAwake: stayAwake ?? this.stayAwake,
    lockOnClose: lockOnClose ?? this.lockOnClose,
    alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
    autoStart: autoStart ?? this.autoStart,
    minimize: minimize ?? this.minimize,
    wifi: wifi ?? this.wifi,
  );
}

/// Lecture et écriture des réglages sur le disque.
class SettingsStore {
  static T _byName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  Future<Settings> load() async {
    final prefs = await SharedPreferences.getInstance();
    const d = Settings();
    final fps = prefs.getInt('fps');
    var wifi = const <WifiAddress>[];
    try {
      final raw = jsonDecode(prefs.getString('wifi') ?? '[]') as List<dynamic>;
      wifi = [
        for (final entry in raw.whereType<Map<String, dynamic>>())
          if ((entry['address'] as String? ?? '').isNotEmpty) WifiAddress.fromJson(entry),
      ];
    } on Object {
      // Liste illisible : on repart d'une liste vide plutôt que de bloquer le démarrage.
    }
    return Settings(
      theme: _byName(AppThemeMode.values, prefs.getString('theme'), d.theme),
      quality: _byName(Quality.values, prefs.getString('quality'), d.quality),
      fps: Settings.fpsChoices.contains(fps) ? fps! : d.fps,
      windowSize: _byName(WindowSize.values, prefs.getString('windowSize'), d.windowSize),
      keyboard: _byName(KeyboardMode.values, prefs.getString('keyboard'), d.keyboard),
      audio: prefs.getBool('audio') ?? d.audio,
      screenOff: prefs.getBool('screenOff') ?? d.screenOff,
      stayAwake: prefs.getBool('stayAwake') ?? d.stayAwake,
      lockOnClose: prefs.getBool('lockOnClose') ?? d.lockOnClose,
      alwaysOnTop: prefs.getBool('alwaysOnTop') ?? d.alwaysOnTop,
      autoStart: prefs.getBool('autoStart') ?? d.autoStart,
      minimize: prefs.getBool('minimize') ?? d.minimize,
      wifi: wifi,
    );
  }

  Future<void> save(Settings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', s.theme.name);
    await prefs.setString('quality', s.quality.name);
    await prefs.setInt('fps', s.fps);
    await prefs.setString('windowSize', s.windowSize.name);
    await prefs.setString('keyboard', s.keyboard.name);
    await prefs.setBool('audio', s.audio);
    await prefs.setBool('screenOff', s.screenOff);
    await prefs.setBool('stayAwake', s.stayAwake);
    await prefs.setBool('lockOnClose', s.lockOnClose);
    await prefs.setBool('alwaysOnTop', s.alwaysOnTop);
    await prefs.setBool('autoStart', s.autoStart);
    await prefs.setBool('minimize', s.minimize);
    await prefs.setString('wifi', jsonEncode([for (final w in s.wifi) w.toJson()]));
  }
}
