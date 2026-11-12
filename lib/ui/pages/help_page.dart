import 'package:flutter/material.dart';

import '../shortcuts.dart';
import '../theme.dart';
import '../widgets/tiles.dart';
import 'page_scaffold.dart';

/// Mode d'emploi : préparer le téléphone (une seule fois), puis les raccourcis de la
/// fenêtre du téléphone.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return AppPage(
      header: const PageHeader(title: 'Mode d\'emploi'),
      children: [
        const SectionTitle('Première connexion', detail: 'une seule fois'),
        const Tile(
          child: StepList([
            'Sur le téléphone : Paramètres → À propos du téléphone → Informations sur le logiciel, puis touchez '
                'sept fois « Numéro de version ».',
            'Revenez dans Paramètres → Options de développement (tout en bas) et activez « Débogage USB ».',
            'Branchez le téléphone au PC avec un câble USB qui transmet les données.',
            'Sur le téléphone, cochez « Toujours autoriser sur cet ordinateur » puis touchez « Autoriser ».',
          ]),
        ),
        const SizedBox(height: Dim.gap),
        Tile(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('En cas de souci', style: t.itemTitle),
              const SizedBox(height: 8),
              const _Tip(
                'L\'option « Débogage USB » est grisée',
                'Sur Samsung, désactivez Paramètres → Sécurité et confidentialité → Blocage auto.',
              ),
              const _Tip(
                'Le téléphone n\'apparaît pas',
                'Essayez un autre câble ou une autre prise USB. Si Windows ne le reconnaît toujours pas, installez '
                    'le pilote « Samsung USB Driver » depuis developer.samsung.com.',
              ),
              const _Tip(
                'Rien ne se passe quand je clique ou que je tape',
                'Dans les options de développement, vérifiez que le débogage USB est bien activé puis rebranchez '
                    'le téléphone.',
              ),
              const _Tip(
                'L\'image saccade en Wi-Fi',
                'Choisissez la qualité « Fluide » dans les réglages, ou rapprochez le téléphone de la box.',
                last: true,
              ),
            ],
          ),
        ),

        const SectionTitle('Raccourcis', detail: 'dans la fenêtre du téléphone'),
        Tile(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Column(
            children: [for (final (keys, effect) in shortcuts) ShortcutRow(keys: keys, effect: effect)],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Le clavier du PC écrit directement dans l\'application ouverte sur le téléphone. '
          'La touche Windows peut remplacer Alt dans tous les raccourcis.',
          style: t.caption,
        ),
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.problem, this.solution, {this.last = false});

  final String problem;
  final String solution;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(problem, style: t.body.copyWith(fontWeight: FontWeight.w600)),
          Text(solution, style: t.secondary),
        ],
      ),
    );
  }
}
