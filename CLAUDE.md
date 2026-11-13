# sPhone — notes pour Claude

- **Toujours communiquer avec l'utilisateur en français.** L'interface, les commentaires
  et les messages de commit sont aussi en français.
- Application Flutter pour **Windows** : affiche l'écran d'un téléphone Android (celui de
  l'utilisateur est un Samsung Galaxy S25) dans une fenêtre au format du téléphone, et
  permet de le contrôler au clavier et à la souris, en USB ou en Wi-Fi.
- L'affichage lui-même est fait par **scrcpy**, lancé par l'application
  (`lib/data/scrcpy.dart`). scrcpy et adb ne sont pas dans le dépôt : la compilation les
  télécharge (`tools/scrcpy.ps1`, version et empreinte dans `tools/scrcpy.json`) et les
  place dans le dossier `scrcpy` à côté de `sphone.exe`. Changer de version : mettre à jour
  `tools/scrcpy.json` **et** `scrcpyVersion`, et relire la documentation de scrcpy pour les
  options (elles changent d'une version majeure à l'autre).
- L'application parle au service adb par son protocole réseau local (`lib/data/adb/adb_client.dart`),
  sans lancer `adb.exe` à chaque question. Seul `adb start-server` est lancé, **détaché** :
  le service hériterait sinon des sorties du programme et l'attente ne finirait jamais.
- Direction artistique : celle de **sDash** (autre application de l'utilisateur). Interface
  à plat (ni texture, ni flou, ni dégradé décoratif), tons chauds, thème clair et sombre,
  police Outfit.
  - Couleurs uniquement par rôle : `context.colors` / `context.text` (`lib/ui/theme.dart`),
    jamais de couleur en dur dans un widget.
  - Tuile ambrée = écran du téléphone affiché, tuile neutre sinon (`Tile`).
  - Composants dans `lib/ui/widgets/` ; chaque page passe par `AppPage` (`page_scaffold.dart`).
  - La fenêtre est étroite (420 × 860 par défaut, 360 × 480 au minimum) : tout doit tenir
    sans débordement à ces tailles.
- Vérifications avant de pousser : `flutter analyze` et `flutter test`. Les tests n'ont
  besoin ni de Windows ni d'un téléphone : `test/support/fake_adb.dart` joue le service adb,
  `test/support/fake_process.dart` joue scrcpy. `test/app_test.dart` parcourt toutes les
  pages à trois tailles de fenêtre.
- Formatage : `dart format -l 120 lib test`.
- Captures de la documentation : `SPHONE_CAPTURES=1 flutter test test/captures_test.dart`.
- La CI (`.github/workflows/build-windows.yml`, machine Windows) compile, essaie les vrais
  `adb.exe` et `scrcpy.exe` sans téléphone (`test/windows_tools_test.dart`), lance
  l'application assemblée, puis produit `sphone-setup.exe` (Inno Setup,
  `tools/installer/sphone.iss`) et `sphone-windows.zip` (artefact `sphone-windows`).
  La Release n'est publiée que sur `main` ou à la demande.
- Logo : sPhone et sDash forment la marque « s » de l'utilisateur, qui a demandé que leurs
  logos aient un point commun tout en étant bien distincts. Règles : même carré arrondi
  orange `#C2571A`, même trait clair à bouts ronds, et **le point ambre toujours au même
  endroit et de la même taille** (en haut à droite). Seul le dessin change : téléphone pour
  sPhone, maison pour sDash ; le « S » seul est le signe de la marque. Ne pas revenir à un
  « S » décliné d'une appli à l'autre (jugé trop peu différent).
  Source : `tools/logo/generer_logo.py` (identique dans les dépôts sDash, sPhone et sDrop, à garder synchronisé)
  → `docs/logo/*.svg`, puis `tools/logo/exporter.py` → PNG (`assets/branding`, `assets/mirror`)
  et icône Windows. Les fichiers de `assets/mirror` portent les noms imposés par scrcpy.
