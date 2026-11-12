import 'package:flutter/material.dart';

import '../../models/phone.dart';
import '../../state/phone_controller.dart';
import '../../state/phone_scope.dart';
import '../shortcuts.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/tiles.dart';
import 'help_page.dart';
import 'page_scaffold.dart';
import 'settings_page.dart';
import 'wifi_page.dart';

void _open(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

/// Page d'accueil : les téléphones visibles et, pour chacun, le bouton qui affiche son écran.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = PhoneScope.of(context);
    final phones = controller.phones;
    final saved = controller.settings.wifi;
    final ready = phones.where((p) => p.ready).length;

    return AppPage(
      header: const _HomeHeader(),
      children: [
        const NoticeArea(),
        if (!controller.tools.complete)
          const Padding(
            padding: EdgeInsets.only(bottom: Dim.gap),
            child: MessageBanner(
              error: true,
              message:
                  'Les programmes scrcpy et adb sont introuvables. Réinstallez sPhone : ils doivent se trouver '
                  'dans le dossier « scrcpy » à côté de l\'application.',
            ),
          )
        else if (controller.service == ServiceState.failed)
          Padding(
            padding: const EdgeInsets.only(bottom: Dim.gap),
            child: MessageBanner(error: true, busy: true, message: '${controller.serviceError} Nouvel essai en cours…'),
          ),
        SectionTitle('Téléphones', detail: phones.isEmpty ? null : '$ready prêt${ready > 1 ? 's' : ''}'),
        if (phones.isEmpty)
          controller.service == ServiceState.starting && controller.tools.complete
              ? const MessageBanner(busy: true, message: 'Recherche des téléphones…')
              : EmptyHint(
                  icon: Icons.smartphone_rounded,
                  title: 'Aucun téléphone détecté',
                  text: 'Branchez votre téléphone avec un câble USB, ou connectez-le en Wi-Fi.',
                  action: AppButton(
                    label: 'Première connexion : mode d\'emploi',
                    icon: Icons.help_outline_rounded,
                    onPressed: () => _open(context, const HelpPage()),
                  ),
                )
        else
          for (final phone in phones)
            Padding(
              padding: const EdgeInsets.only(bottom: Dim.gap),
              child: _PhoneTile(phone: phone),
            ),
        SectionTitle('Wi-Fi', detail: saved.isEmpty ? 'sans câble' : null),
        for (final entry in saved)
          Padding(
            padding: const EdgeInsets.only(bottom: Dim.gap),
            child: _WifiTile(entry: entry),
          ),
        AppButton(
          label: saved.isEmpty ? 'Connecter un téléphone en Wi-Fi' : 'Ajouter un téléphone en Wi-Fi',
          icon: Icons.wifi_rounded,
          expand: true,
          onPressed: () => _open(context, const WifiPage()),
        ),
        SectionTitle(
          'Raccourcis',
          trailing: InkWell(
            onTap: () => _open(context, const HelpPage()),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text('Tout voir', style: context.text.button.copyWith(color: context.colors.accent)),
            ),
          ),
        ),
        Tile(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Column(
            children: [
              for (final (keys, effect) in shortcuts.take(essentialCount)) ShortcutRow(keys: keys, effect: effect),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Row(
      children: [
        Image.asset('assets/branding/logo.png', height: 44, filterQuality: FilterQuality.medium),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('sPhone', style: t.pageTitle),
              Text('Le téléphone sur le PC', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption),
            ],
          ),
        ),
        SquareButton(
          icon: Icons.help_outline_rounded,
          tooltip: 'Mode d\'emploi et raccourcis',
          onPressed: () => _open(context, const HelpPage()),
        ),
        const SizedBox(width: 8),
        SquareButton(
          icon: Icons.tune_rounded,
          tooltip: 'Réglages',
          onPressed: () => _open(context, const SettingsPage()),
        ),
      ],
    );
  }
}

/// Un téléphone : son état, et les actions possibles. Ambré quand son écran est affiché.
class _PhoneTile extends StatelessWidget {
  const _PhoneTile({required this.phone});

  final Phone phone;

  String _status(bool mirroring, LinkKind? mirrorKind) {
    if (mirroring) return 'Écran affiché · ${mirrorKind == LinkKind.wifi ? 'Wi-Fi' : 'USB'}';
    if (phone.hasUsb && phone.hasWifi) return 'Branché en USB · Wi-Fi actif';
    if (phone.hasUsb) return 'Branché en USB';
    if (phone.hasWifi) return 'Connecté en Wi-Fi';
    if (phone.needsAuthorization) return 'En attente de votre autorisation';
    if (phone.links.any((l) => l.state == LinkState.connecting)) return 'Connexion…';
    return 'Hors ligne';
  }

  @override
  Widget build(BuildContext context) {
    final controller = PhoneScope.of(context);
    final c = context.colors;
    final t = context.text;
    final mirroring = controller.isMirroring(phone);
    final wifiOnly = phone.linkOf(LinkKind.usb) == null;

    return Tile(
      active: mirroring,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconBadge(
                icon: wifiOnly ? Icons.wifi_rounded : Icons.usb_rounded,
                tone: mirroring ? BadgeTone.onActive : BadgeTone.neutral,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      phone.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.itemTitle.copyWith(color: mirroring ? c.onActive : c.text),
                    ),
                    Text(
                      _status(mirroring, controller.session?.kind),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.secondary.copyWith(color: mirroring ? c.onActive.withValues(alpha: 0.8) : c.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (phone.ready) ...[
            if (mirroring)
              AppButton(
                label: 'Arrêter l\'affichage',
                icon: Icons.stop_rounded,
                expand: true,
                onPressed: controller.stopMirror,
              )
            else
              AppButton(
                label: 'Afficher l\'écran',
                icon: Icons.play_arrow_rounded,
                kind: ButtonKind.primary,
                expand: true,
                onPressed: controller.tools.complete ? () => controller.startMirror(phone) : null,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (phone.hasUsb && !phone.hasWifi) ...[
                  Expanded(
                    child: AppButton(
                      label: 'Passer en Wi-Fi',
                      icon: Icons.wifi_rounded,
                      compact: true,
                      expand: true,
                      busy: controller.isBusy('wifi:${phone.id}'),
                      onPressed: () => controller.enableWifi(phone),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: AppButton(
                    label: 'Capture d\'écran',
                    icon: Icons.photo_camera_outlined,
                    compact: true,
                    expand: true,
                    busy: controller.isBusy('shot:${phone.id}'),
                    onPressed: () => controller.takeScreenshot(phone),
                  ),
                ),
              ],
            ),
          ] else if (phone.needsAuthorization)
            Text(
              'Déverrouillez le téléphone, cochez « Toujours autoriser sur cet ordinateur » puis touchez « Autoriser ».',
              style: t.secondary,
            )
          else
            Text(
              'Le téléphone est visible mais ne répond pas encore. Déverrouillez-le ou rebranchez le câble.',
              style: t.secondary,
            ),
        ],
      ),
    );
  }
}

/// Un téléphone mémorisé pour le Wi-Fi : reconnexion en un clic.
class _WifiTile extends StatelessWidget {
  const _WifiTile({required this.entry});

  final WifiAddress entry;

  @override
  Widget build(BuildContext context) {
    final controller = PhoneScope.of(context);
    final c = context.colors;
    final t = context.text;
    final connected = controller.isConnected(entry);
    return Tile(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.name.isEmpty ? entry.address : entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.itemTitle,
                ),
                Row(
                  children: [
                    StatusDot(color: connected ? c.success : c.textFaint),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        connected ? 'Connecté · ${entry.address}' : 'Non connecté · ${entry.address}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!connected) ...[
            AppButton(
              label: 'Connecter',
              compact: true,
              busy: controller.isBusy('connect:${entry.address}'),
              onPressed: () => controller.connectAddress(entry.address, name: entry.name),
            ),
            const SizedBox(width: 8),
          ],
          SquareButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Oublier ce téléphone',
            onPressed: () => controller.forgetWifi(entry),
          ),
        ],
      ),
    );
  }
}
