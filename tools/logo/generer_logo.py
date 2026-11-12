"""Logo sPhone : le « S » de sDash (un seul trait, terminé par un point allumé) posé sur
une silhouette de téléphone.

Utilisation (nécessite `pip install fonttools`, pour vectoriser le texte du logotype) :

    python3 tools/logo/generer_logo.py assets/fonts docs/logo

Produit, dans le dossier de sortie :

    sphone-logo.svg             icône : téléphone orange, « S » clair, point ambre
    sphone-logo-petit.svg       variante simplifiée pour les petites tailles (≤ 32 px)
    sphone-deconnecte.svg       téléphone éteint : affiché quand la liaison est coupée
    sphone-logotype.svg         icône + « sPhone », pour fond clair
    sphone-logotype-sombre.svg  icône + « sPhone », pour fond sombre

Les PNG et l'icône Windows sont des exports de ces SVG : `tools/logo/exporter.py`.
"""

import sys

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

FONTS, OUT = sys.argv[1], sys.argv[2]

# Mêmes couleurs que le logo sDash.
FOND, TRAIT, POINT = '#C2571A', '#FFF6EA', '#FFC56E'
# Téléphone éteint : bruns neutres du thème sombre, pas de point allumé.
FOND_ETEINT, TRAIT_ETEINT = '#4A3A2E', '#A8937F'

# ── Géométrie du « S », identique à celle de sDash (carré de 1024) ──
# Un seul trait épais à bouts ronds : barre haute, demi-cercle à gauche, barre médiane,
# demi-cercle à droite, barre basse. L'extrémité haute est détachée en un point.
RAYON = 108
TRAIT_S = 120
X_GAUCHE, X_DROITE = 437, 587
Y_HAUT, Y_MILIEU, Y_BAS = 296, 512, 728
ESPACE = 36

X_POINT = X_DROITE + RAYON
FIN_BARRE_HAUTE = X_POINT - TRAIT_S - ESPACE
TRACE = (
    f'M{FIN_BARRE_HAUTE} {Y_HAUT} H{X_GAUCHE} '
    f'A{RAYON} {RAYON} 0 0 0 {X_GAUCHE} {Y_MILIEU} H{X_DROITE} '
    f'A{RAYON} {RAYON} 0 0 1 {X_DROITE} {Y_BAS} H{X_GAUCHE - RAYON}'
)


def glyphe(echelle, centre_y, trait, point):
    """Le « S » centré horizontalement, à l'échelle et à la hauteur voulues."""
    dessin = (
        f'<path d="{TRACE}" fill="none" stroke="{trait}" stroke-width="{TRAIT_S}" '
        f'stroke-linecap="round" stroke-linejoin="round"/>'
    )
    if point:
        dessin += f'<circle cx="{X_POINT}" cy="{Y_HAUT}" r="{TRAIT_S / 2:g}" fill="{point}"/>'
    return f'<g transform="translate(512 {centre_y}) scale({echelle}) translate(-512 -512)">{dessin}</g>'


def telephone(largeur, hauteur, rayon, fond):
    """Corps du téléphone : rectangle arrondi vertical, centré dans le carré de 1024."""
    return (
        f'<rect x="{(1024 - largeur) / 2:g}" y="{(1024 - hauteur) / 2:g}" width="{largeur}" '
        f'height="{hauteur}" rx="{rayon}" fill="{fond}"/>'
    )


def barre_de_gestes(y, largeur, couleur):
    """Petit trait en bas de l'écran : c'est lui qui fait lire la forme comme un téléphone."""
    return (
        f'<rect x="{(1024 - largeur) / 2:g}" y="{y}" width="{largeur}" height="26" rx="13" '
        f'fill="{couleur}" fill-opacity="0.5"/>'
    )


def svg(contenu, largeur=1024, hauteur=1024):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {largeur} {hauteur}" '
        f'width="{largeur}" height="{hauteur}">{contenu}</svg>\n'
    )


def icone(fond, trait, point):
    return telephone(624, 984, 150, fond) + glyphe(0.86, 478, trait, point) + barre_de_gestes(884, 196, trait)


ICONE = icone(FOND, TRAIT, POINT)
# Petites tailles : téléphone plus trapu et « S » plus gros, sans la barre de gestes.
ICONE_PETITE = telephone(720, 984, 170, FOND) + glyphe(1.04, 512, TRAIT, POINT)

open(f'{OUT}/sphone-logo.svg', 'w').write(svg(ICONE))
open(f'{OUT}/sphone-logo-petit.svg', 'w').write(svg(ICONE_PETITE))
open(f'{OUT}/sphone-deconnecte.svg', 'w').write(svg(icone(FOND_ETEINT, TRAIT_ETEINT, None)))


# ── Logotype : icône + « sPhone », lettres converties en tracés (aucune police requise) ──
def texte(police, chaine, taille, x, ligne_de_base, espacement=0.0):
    glyphes, table = police.getGlyphSet(), police.getBestCmap()
    echelle = taille / police['head'].unitsPerEm
    plume, curseur = SVGPathPen(glyphes), x
    for caractere in chaine:
        g = glyphes[table[ord(caractere)]]
        if caractere != ' ':
            g.draw(TransformPen(plume, (echelle, 0, 0, -echelle, curseur, ligne_de_base)))
        curseur += g.width * echelle + espacement
    return plume.getCommands(), curseur - x


SEMI = TTFont(f'{FONTS}/Outfit_600SemiBold.ttf')
MEDIUM = TTFont(f'{FONTS}/Outfit_500Medium.ttf')
X_TEXTE = 470
s_trace, s_largeur = texte(SEMI, 's', 250, X_TEXTE, 330)
phone_trace, phone_largeur = texte(SEMI, 'Phone', 250, X_TEXTE + s_largeur + 4, 330)
devise_trace, _ = texte(MEDIUM, 'LE TÉLÉPHONE SUR LE PC', 40, X_TEXTE + 8, 420, espacement=7)
LARGEUR = round(X_TEXTE + s_largeur + 4 + phone_largeur + 70)


def logotype(couleur_s, couleur_phone, couleur_devise):
    return svg(
        f'<svg x="0" y="40" width="480" height="480" viewBox="0 0 1024 1024">{ICONE}</svg>'
        f'<path d="{s_trace}" fill="{couleur_s}"/>'
        f'<path d="{phone_trace}" fill="{couleur_phone}"/>'
        f'<path d="{devise_trace}" fill="{couleur_devise}"/>',
        LARGEUR,
        560,
    )


open(f'{OUT}/sphone-logotype.svg', 'w').write(logotype('#C2571A', '#2A1D14', '#6B5A4C'))
open(f'{OUT}/sphone-logotype-sombre.svg', 'w').write(logotype('#F0A257', '#F7EEE3', '#BCA996'))
print(f'Logo généré dans {OUT}')
