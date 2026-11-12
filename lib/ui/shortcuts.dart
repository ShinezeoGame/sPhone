/// Raccourcis de la fenêtre du téléphone (ceux de scrcpy), dans l'ordre d'utilité.
/// Les [essentialCount] premiers sont rappelés sur la page d'accueil.
const shortcuts = <(List<String> keys, String effect)>[
  (['Clic'], 'Toucher l\'écran'),
  (['Clic droit'], 'Retour'),
  (['Clic molette'], 'Accueil'),
  (['Alt', 'S'], 'Applications récentes'),
  (['Ctrl', 'C'], 'Copier, puis Ctrl + V pour coller entre le PC et le téléphone'),
  (['Alt', '↑'], 'Monter le volume (Alt + ↓ pour le baisser)'),
  (['Alt', 'N'], 'Ouvrir les notifications (Alt + Maj + N pour refermer)'),
  (['Alt', 'P'], 'Bouton marche / veille'),
  (['Alt', 'O'], 'Éteindre l\'écran du téléphone (Alt + Maj + O pour le rallumer)'),
  (['Alt', 'R'], 'Pivoter l\'écran'),
  (['Alt', 'F'], 'Plein écran'),
  (['Alt', 'W'], 'Ajuster la fenêtre à l\'image'),
  (['Ctrl', 'Clic'], 'Maintenir et déplacer la souris pour zoomer (pincer)'),
  (['Glisser'], 'Déposer un fichier dans la fenêtre l\'envoie sur le téléphone ; un fichier APK est installé'),
];

const essentialCount = 5;
