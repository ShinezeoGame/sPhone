import 'package:flutter/material.dart';

import '../theme.dart';

/// Surface de base de l'interface : fond uni, bord fin, coins arrondis.
/// Devient ambrée quand [active] est vrai (écran du téléphone affiché).
class Tile extends StatelessWidget {
  const Tile({
    super.key,
    required this.child,
    this.onTap,
    this.active = false,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool active;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: active ? c.active : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dim.tileRadius),
        side: BorderSide(color: active ? c.active : c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

enum BadgeTone {
  /// Sur une tuile neutre.
  neutral,

  /// Sur une tuile ambrée.
  onActive,

  /// Pastille orange : élément mis en avant.
  accent,
}

/// Pastille ronde contenant une icône.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, this.tone = BadgeTone.neutral, this.size = 40});

  final IconData icon;
  final BadgeTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (background, foreground) = switch (tone) {
      BadgeTone.neutral => (c.surfaceMuted, c.textMuted),
      BadgeTone.onActive => (c.onActive.withValues(alpha: 0.12), c.onActive),
      BadgeTone.accent => (c.accent, c.onAccent),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.52, color: foreground),
    );
  }
}

/// Titre de section, avec une action facultative à droite.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.detail, this.trailing});

  final String title;

  /// Précision affichée après le titre (« 1 connecté »).
  final String? detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Padding(
      padding: const EdgeInsets.only(top: Dim.sectionGap, bottom: 8, left: 2, right: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: t.sectionTitle),
          if (detail != null) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Text(detail!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.secondary),
            ),
          ],
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

/// Point d'état coloré.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 9});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Message affiché quand il n'y a rien à montrer.
class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.icon, required this.title, required this.text, this.action});

  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Tile(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: c.textFaint),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: t.itemTitle),
          const SizedBox(height: 4),
          Text(text, textAlign: TextAlign.center, style: t.secondary),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Bandeau de message : information (fond orangé) ou erreur (fond rouge pâle).
class MessageBanner extends StatelessWidget {
  const MessageBanner({super.key, required this.message, this.error = false, this.busy = false, this.onClose});

  final String message;
  final bool error;

  /// Remplace l'icône par un indicateur d'attente.
  final bool busy;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = error ? c.danger : c.text;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(
          color: error ? c.dangerSoft : c.accentSoft,
          borderRadius: BorderRadius.circular(Dim.tileRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: busy
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
                  : Icon(error ? Icons.error_outline_rounded : Icons.info_outline_rounded, size: 20, color: fg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(message, style: context.text.secondary.copyWith(color: c.text)),
              ),
            ),
            if (onClose != null)
              IconButton(
                onPressed: onClose,
                tooltip: 'Fermer',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, size: 18, color: c.textMuted),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// Ligne de réglage : titre, explication, commande à droite.
class SettingRow extends StatelessWidget {
  const SettingRow({super.key, required this.title, this.subtitle, required this.trailing});

  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: t.body),
                if (subtitle != null) Text(subtitle!, style: t.caption),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

/// Réglage à choix : titre et explication au-dessus, commande sur toute la largeur.
class SettingBlock extends StatelessWidget {
  const SettingBlock({super.key, required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: t.body),
          const SizedBox(height: 8),
          child,
          if (subtitle != null) ...[const SizedBox(height: 6), Text(subtitle!, style: t.caption)],
        ],
      ),
    );
  }
}

/// Liste d'étapes numérotées.
class StepList extends StatelessWidget {
  const StepList(this.steps, {super.key});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, step) in steps.indexed)
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.surfaceMuted, shape: BoxShape.circle),
                  child: Text(
                    '${index + 1}',
                    style: t.caption.copyWith(color: c.text, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(step, style: t.body),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Un raccourci : les touches (ou le geste de souris) à gauche, l'effet à droite.
class ShortcutRow extends StatelessWidget {
  const ShortcutRow({super.key, required this.keys, required this.effect});

  /// Touches à enfoncer ensemble (« Alt », « S »), ou un geste (« Clic droit »).
  final List<String> keys;
  final String effect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final key in keys)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.surfaceMuted,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: c.border),
                    ),
                    child: Text(key, style: t.key),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(effect, style: t.secondary.copyWith(color: c.text)),
          ),
        ],
      ),
    );
  }
}
