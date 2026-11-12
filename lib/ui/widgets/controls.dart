import 'package:flutter/material.dart';

import '../theme.dart';

enum ButtonKind { primary, secondary }

/// Bouton texte. `primary` : action principale de l'écran ; `secondary` : action courante.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = ButtonKind.secondary,
    this.compact = false,
    this.expand = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonKind kind;
  final bool compact;

  /// Occupe toute la largeur disponible.
  final bool expand;

  /// Affiche un indicateur d'attente à la place de l'icône et bloque les clics.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null && !busy;
    final primary = kind == ButtonKind.primary;
    final fg = primary ? c.onAccent : c.text;
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.text.button.copyWith(color: fg),
    );
    final Widget? leading = busy
        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
        : (icon != null ? Icon(icon, size: 20, color: fg) : null);
    return Opacity(
      opacity: onPressed == null && !busy ? 0.45 : 1,
      child: Material(
        color: primary ? c.accent : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dim.buttonRadius),
          side: primary ? BorderSide.none : BorderSide(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Container(
            height: compact ? 40 : 46,
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 8)],
                Flexible(child: text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton carré à icône.
class SquareButton extends StatelessWidget {
  const SquareButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 40,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Libellé de l'action, lu par les lecteurs d'écran et affiché en info-bulle.
  final String tooltip;
  final double size;

  /// Affiche un indicateur d'attente et bloque les clics.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Opacity(
          opacity: onPressed == null && !busy ? 0.4 : 1,
          child: SizedBox(
            width: size,
            height: size,
            child: Material(
              color: c.surfaceMuted,
              borderRadius: BorderRadius.circular(Dim.buttonRadius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? onPressed : null,
                child: Center(
                  child: busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: c.text),
                        )
                      : Icon(icon, size: size * 0.52, color: c.text),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Interrupteur.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged, this.label});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      toggled: value,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: 50,
              height: 30,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: value ? c.accent : c.surfaceMuted,
                border: Border.all(color: value ? c.accent : c.border),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: value ? c.onAccent : c.textMuted),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Choix exclusif : une rangée de segments égaux, le segment choisi est rempli.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.height = 44,
  });

  final List<T> values;
  final T? selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(Dim.buttonRadius)),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == selected,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelected(v),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: v == selected ? c.accent : c.accent.withValues(alpha: 0),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          labelOf(v),
                          maxLines: 1,
                          style: t.button.copyWith(fontSize: 14, color: v == selected ? c.onAccent : c.text),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
