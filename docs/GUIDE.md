# Guide d'utilisation de sPhone

[← Retour à la présentation](../README.md)

## Installation

1. Téléchargez **sphone-setup.exe** depuis la [dernière version](https://github.com/ShinezeoGame/sPhone/releases/latest)
   et lancez-le. L'application n'est pas signée : si Windows affiche « Windows a protégé
   votre ordinateur », cliquez sur « Informations complémentaires » puis « Exécuter quand même ».
2. L'installation se fait dans votre profil, sans droits d'administrateur.

Une version portable (`sphone-windows.zip`, à décompresser) est proposée avec chaque version.
Les compilations de chaque branche sont aussi disponibles en artefact **sphone-windows**
dans l'onglet **Actions**.

## Première connexion (une seule fois)

Sur un Samsung Galaxy — les intitulés varient peu sur les autres téléphones :

1. **Paramètres → À propos du téléphone → Informations sur le logiciel**, touchez sept fois
   « Numéro de version » : les options de développement apparaissent.
2. **Paramètres → Options de développement**, activez **Débogage USB**.
3. Branchez le téléphone au PC avec un câble USB qui transmet les données.
4. Sur le téléphone, cochez « Toujours autoriser sur cet ordinateur » puis **Autoriser**.

sPhone affiche alors le téléphone et ouvre son écran.

| Souci | Solution |
| --- | --- |
| « Débogage USB » est grisé | Désactivez **Paramètres → Sécurité et confidentialité → Blocage auto**. |
| Le téléphone n'apparaît pas | Essayez un autre câble ou une autre prise USB. Sinon, installez le pilote [Samsung USB Driver](https://developer.samsung.com/android-usb-driver). |
| Rien ne se passe au clic ou au clavier | Vérifiez que le débogage USB est activé, puis rebranchez le téléphone. |
| L'image saccade en Wi-Fi | Choisissez la qualité « Fluide » dans les réglages. |

## Wi-Fi

Le téléphone et le PC doivent être sur le même réseau.

- **Avec le câble (le plus simple)** : téléphone branché, cliquez sur **Passer en Wi-Fi**,
  puis débranchez. sPhone mémorise l'adresse et s'y reconnecte au lancement. À refaire
  après un redémarrage du téléphone.
- **Sans câble** : dans **Options de développement → Débogage sans fil**, touchez
  « Associer l'appareil avec un code d'association » et recopiez l'adresse et le code dans
  sPhone (**Connecter un téléphone en Wi-Fi**).

## Clavier

- **Simple** (par défaut) : fonctionne sans réglage ; certains caractères spéciaux peuvent manquer.
- **Clavier physique** : le PC est vu comme un clavier branché au téléphone, tous les
  caractères et raccourcis passent. À régler une fois sur le téléphone : disposition
  « Français (AZERTY) » (bouton **Régler la disposition sur le téléphone** dans les réglages).

## Raccourcis dans la fenêtre du téléphone

| Geste ou touches | Effet |
| --- | --- |
| Clic | Toucher l'écran |
| Clic droit | Retour |
| Clic molette | Accueil |
| Alt + S | Applications récentes |
| Ctrl + C, Ctrl + V | Copier-coller entre le PC et le téléphone |
| Alt + ↑ / Alt + ↓ | Volume |
| Alt + N | Notifications (Alt + Maj + N pour refermer) |
| Alt + P | Bouton marche / veille |
| Alt + O | Éteindre l'écran du téléphone (Alt + Maj + O pour le rallumer) |
| Alt + R | Pivoter l'écran |
| Alt + F | Plein écran |
| Alt + W | Ajuster la fenêtre à l'image |
| Ctrl + clic maintenu | Zoomer (pincer) |
| Glisser un fichier | L'envoyer sur le téléphone (un APK est installé) |

La touche Windows peut remplacer Alt dans tous les raccourcis.

## Réglages utiles

- **Qualité** : Fluide (Wi-Fi capricieux), Équilibrée, ou Nette (définition native, idéale en USB).
- **Images par seconde** : 30, 60 ou 120.
- **Son du téléphone sur le PC**, **Toujours au premier plan**, **Afficher dès la connexion**,
  **Réduire sPhone pendant l'affichage**.
- **Éteindre son écran pendant l'affichage**, **Empêcher la mise en veille** (en USB),
  **Verrouiller à la fermeture**.
