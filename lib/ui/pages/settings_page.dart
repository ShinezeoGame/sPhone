import 'package:flutter/material.dart';

import '../../data/scrcpy.dart';
import '../../data/settings.dart';
import '../../state/phone_scope.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/tiles.dart';
import 'page_scaffold.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = PhoneScope.of(context);
    final s = controller.settings;
    final t = context.text;
    final readyPhone = controller.phones.where((p) => p.ready).firstOrNull;

    void set(Settings next) => controller.updateSettings(next);

    return AppPage(
      header: const PageHeader(title: 'Réglages'),
      children: [
        const NoticeArea(),
        if (controller.session != null)
          const MessageBanner(message: 'Les changements s\'appliqueront au prochain affichage de l\'écran.'),

        const SectionTitle('Fenêtre du téléphone'),
        Tile(
          child: Column(
            children: [
              SettingBlock(
                title: 'Taille',
                subtitle: 'La fenêtre garde le format du téléphone ; vous pouvez aussi l\'étirer à la souris.',
                child: Segmented<WindowSize>(
                  values: WindowSize.values,
                  selected: s.windowSize,
                  labelOf: (v) => switch (v) {
                    WindowSize.compact => 'Petite',
                    WindowSize.medium => 'Moyenne',
                    WindowSize.large => 'Grande',
                    WindowSize.auto => 'Maximale',
                  },
                  onSelected: (v) => set(s.copyWith(windowSize: v)),
                ),
              ),
              SettingRow(
                title: 'Toujours au premier plan',
                subtitle: 'La fenêtre du téléphone reste au-dessus des autres.',
                trailing: AppSwitch(
                  value: s.alwaysOnTop,
                  onChanged: (v) => set(s.copyWith(alwaysOnTop: v)),
                ),
              ),
              SettingRow(
                title: 'Afficher dès la connexion',
                subtitle: 'L\'écran s\'ouvre tout seul quand un téléphone est branché ou connecté.',
                trailing: AppSwitch(
                  value: s.autoStart,
                  onChanged: (v) => set(s.copyWith(autoStart: v)),
                ),
              ),
              SettingRow(
                title: 'Réduire sPhone pendant l\'affichage',
                subtitle: 'Seule la fenêtre du téléphone reste à l\'écran.',
                trailing: AppSwitch(
                  value: s.minimize,
                  onChanged: (v) => set(s.copyWith(minimize: v)),
                ),
              ),
            ],
          ),
        ),

        const SectionTitle('Image et son'),
        Tile(
          child: Column(
            children: [
              SettingBlock(
                title: 'Qualité',
                subtitle: switch (s.quality) {
                  Quality.smooth => 'Image allégée : à choisir si l\'affichage saccade, surtout en Wi-Fi.',
                  Quality.balanced => 'Bon compromis entre netteté et réactivité.',
                  Quality.sharp => 'Définition native du téléphone : idéale en USB.',
                },
                child: Segmented<Quality>(
                  values: Quality.values,
                  selected: s.quality,
                  labelOf: (v) => switch (v) {
                    Quality.smooth => 'Fluide',
                    Quality.balanced => 'Équilibrée',
                    Quality.sharp => 'Nette',
                  },
                  onSelected: (v) => set(s.copyWith(quality: v)),
                ),
              ),
              SettingBlock(
                title: 'Images par seconde',
                child: Segmented<int>(
                  values: Settings.fpsChoices,
                  selected: s.fps,
                  labelOf: (v) => '$v',
                  onSelected: (v) => set(s.copyWith(fps: v)),
                ),
              ),
              SettingRow(
                title: 'Son du téléphone sur le PC',
                subtitle: 'Le son sort des haut-parleurs du PC au lieu du téléphone.',
                trailing: AppSwitch(
                  value: s.audio,
                  onChanged: (v) => set(s.copyWith(audio: v)),
                ),
              ),
            ],
          ),
        ),

        const SectionTitle('Téléphone'),
        Tile(
          child: Column(
            children: [
              SettingRow(
                title: 'Éteindre son écran pendant l\'affichage',
                subtitle: 'Le téléphone reste utilisable depuis le PC, écran noir : économise la batterie.',
                trailing: AppSwitch(
                  value: s.screenOff,
                  onChanged: (v) => set(s.copyWith(screenOff: v)),
                ),
              ),
              SettingRow(
                title: 'Empêcher la mise en veille',
                subtitle: 'Tant que le téléphone est branché en USB.',
                trailing: AppSwitch(
                  value: s.stayAwake,
                  onChanged: (v) => set(s.copyWith(stayAwake: v)),
                ),
              ),
              SettingRow(
                title: 'Verrouiller à la fermeture',
                subtitle: 'Le téléphone se met en veille quand vous fermez sa fenêtre.',
                trailing: AppSwitch(
                  value: s.lockOnClose,
                  onChanged: (v) => set(s.copyWith(lockOnClose: v)),
                ),
              ),
            ],
          ),
        ),

        const SectionTitle('Clavier'),
        Tile(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingBlock(
                title: 'Mode de saisie',
                subtitle: switch (s.keyboard) {
                  KeyboardMode.simple => 'Fonctionne sans réglage. Certains caractères spéciaux peuvent manquer.',
                  KeyboardMode.physical =>
                    'Le PC est vu comme un clavier branché au téléphone : tous les caractères et raccourcis passent. '
                        'À régler une fois sur le téléphone : choisissez la disposition « Français (AZERTY) ».',
                },
                child: Segmented<KeyboardMode>(
                  values: KeyboardMode.values,
                  selected: s.keyboard,
                  labelOf: (v) => switch (v) {
                    KeyboardMode.simple => 'Simple',
                    KeyboardMode.physical => 'Clavier physique',
                  },
                  onSelected: (v) => set(s.copyWith(keyboard: v)),
                ),
              ),
              if (s.keyboard == KeyboardMode.physical) ...[
                const SizedBox(height: 4),
                AppButton(
                  label: 'Régler la disposition sur le téléphone',
                  icon: Icons.keyboard_alt_outlined,
                  expand: true,
                  onPressed: readyPhone == null ? null : () => controller.openKeyboardSettings(readyPhone),
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),

        const SectionTitle('Apparence'),
        Tile(
          child: SettingBlock(
            title: 'Thème',
            child: Segmented<AppThemeMode>(
              values: AppThemeMode.values,
              selected: s.theme,
              labelOf: (v) => switch (v) {
                AppThemeMode.auto => 'Automatique',
                AppThemeMode.light => 'Clair',
                AppThemeMode.dark => 'Sombre',
              },
              onSelected: (v) => set(s.copyWith(theme: v)),
            ),
          ),
        ),

        const SizedBox(height: Dim.sectionGap),
        Text(
          'sPhone s\'appuie sur scrcpy $scrcpyVersion et adb, deux logiciels libres (licence Apache 2.0) '
          'fournis dans le dossier « scrcpy » de l\'application.',
          textAlign: TextAlign.center,
          style: t.caption,
        ),
      ],
    );
  }
}
