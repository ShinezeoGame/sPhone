"""Logos de la marque « s » : sDash, sPhone, et le « S » qui les signe.

Le principe, commun à toutes les applications :

  * le même carré arrondi orange ;
  * un dessin d'un seul trait clair, épais, à bouts ronds ;
  * LE POINT ambre, toujours au même endroit (en haut à droite) et de la même taille.
    C'est le point commun de la marque : une lumière allumée, une notification.

Seul le dessin change d'une application à l'autre : une maison pour sDash, un téléphone
pour sPhone. Le « S » seul, dont l'extrémité se détache pour devenir le point, est le signe
de la marque elle-même. Ajouter une application, c'est ajouter un dessin dans `DESSINS`.

Ce fichier est identique dans les dépôts sDash et sPhone ; seule `APPLI_DU_DEPOT` diffère.

Utilisation (nécessite `pip install fonttools`, pour vectoriser le texte du logotype) :

    python3 tools/logo/generer_logo.py assets/fonts docs/logo [sdash|sphone]

Produit, dans le dossier de sortie (ici pour sPhone) :

    sphone-logo.svg             icône complète (carré arrondi)
    sphone-logo-petit.svg       trait et point renforcés, pour les tailles ≤ 32 px
    sphone-logotype.svg         icône + « sPhone », pour fond clair
    sphone-logotype-sombre.svg  icône + « sPhone », pour fond sombre
    sphone-deconnecte.svg       icône éteinte (liaison coupée) — sPhone seulement
    sdash-icone-avant-plan.svg  dessin seul sur fond transparent : couche avant de l'icône
                                adaptative Android — sDash seulement
    sdash-icone-pleine.svg      carré plein sans arrondi, icônes web « maskable » — sDash seulement
    marque-s.svg                le « S » de la marque

Les PNG et les icônes des systèmes sont des exports de ces SVG : `tools/logo/exporter.py`.
"""

import sys

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

APPLI_DU_DEPOT = 'sphone'

FONTS, OUT = sys.argv[1], sys.argv[2]
APPLI = sys.argv[3] if len(sys.argv) > 3 else APPLI_DU_DEPOT

# ── Couleurs ──
FOND, TRAIT, POINT = '#C2571A', '#FFF6EA', '#FFC56E'
# Icône éteinte : bruns neutres du thème sombre, point sans lumière.
FOND_ETEINT, TRAIT_ETEINT, POINT_ETEINT = '#4A3A2E', '#A8937F', '#6B5646'

# ── Constantes de la marque, dans un carré de 1024 ──
ARRONDI = 230  # coins du carré
EPAISSEUR = 92  # épaisseur du trait
X_POINT, Y_POINT, R_POINT = 712, 300, 68  # le point : même place, même taille partout
ESPACE = 38  # vide laissé autour du point quand le dessin passe dessous

# ── Dessins : un tracé par application ──
# Téléphone : contour arrondi, décalé à gauche pour que le point morde son coin.
G, D, H, B, R = 330, 650, 210, 850, 88
TELEPHONE = (
    f'M{G + R} {H} H{D - R} A{R} {R} 0 0 1 {D} {H + R} V{B - R} A{R} {R} 0 0 1 {D - R} {B} '
    f'H{G + R} A{R} {R} 0 0 1 {G} {B - R} V{H + R} A{R} {R} 0 0 1 {G + R} {H} Z'
)
# Petit trait en bas de l'écran (la barre de gestes) : il fait lire le contour comme un
# téléphone plutôt que comme un simple cadre. Trop fin pour les petites tailles, où il disparaît.
BARRE_DE_GESTES = f'M{(G + D) // 2 - 44} {B - 104} H{(G + D) // 2 + 44}'
# Maison : un toit débordant et ses murs ; le point brille au-dessus du toit.
MAISON = 'M222 504 L466 290 L710 504 M286 474 V794 H646 V474'
# « S » : barre haute, demi-cercle à gauche, barre médiane, demi-cercle à droite, barre
# basse. Sa barre haute est à la hauteur du point, qui en est l'extrémité détachée.
RAYON_S = 108
X_GAUCHE, X_DROITE = 438, 590
Y_MILIEU, Y_BAS = Y_POINT + 2 * RAYON_S, Y_POINT + 4 * RAYON_S
FIN_BARRE_HAUTE = X_POINT - R_POINT - ESPACE - EPAISSEUR // 2
S = (
    f'M{FIN_BARRE_HAUTE} {Y_POINT} H{X_GAUCHE} '
    f'A{RAYON_S} {RAYON_S} 0 0 0 {X_GAUCHE} {Y_MILIEU} H{X_DROITE} '
    f'A{RAYON_S} {RAYON_S} 0 0 1 {X_DROITE} {Y_BAS} H{X_GAUCHE - RAYON_S}'
)

DESSINS = {
    'sdash': {'nom': 'Dash', 'trace': MAISON, 'devise': 'TABLEAU DE BORD DOMOTIQUE', 'android': True},
    'sphone': {
        'nom': 'Phone',
        'trace': TELEPHONE,
        'detail': BARRE_DE_GESTES,
        'devise': 'LE TÉLÉPHONE SUR LE PC',
        'eteint': True,
    },
}
A = DESSINS[APPLI]


def dessin(trace, fond=FOND, trait=TRAIT, point=POINT, gras=1.0, detail=None, degage=True):
    """Le dessin et le point. `gras` renforce trait et point pour les petites tailles.

    `degage` efface le dessin autour du point pour lui laisser sa place ; à couper quand
    le fond doit rester transparent (le dessin ne doit alors pas passer sous le point).
    """
    rayon = R_POINT * gras
    fin = ''
    if detail:
        fin = f'<path d="{detail}" fill="none" stroke="{trait}" stroke-width="{EPAISSEUR * 0.42:g}" stroke-linecap="round"/>'
    return (
        f'<path d="{trace}" fill="none" stroke="{trait}" stroke-width="{EPAISSEUR * gras:g}" '
        f'stroke-linecap="round" stroke-linejoin="round"/>{fin}'
        + (f'<circle cx="{X_POINT}" cy="{Y_POINT}" r="{rayon + ESPACE:g}" fill="{fond}"/>' if degage else '')
        + f'<circle cx="{X_POINT}" cy="{Y_POINT}" r="{rayon:g}" fill="{point}"/>'
    )


def carre(fond=FOND, arrondi=ARRONDI):
    return f'<rect width="1024" height="1024" rx="{arrondi}" fill="{fond}"/>'


def reduit(contenu, echelle):
    return f'<g transform="translate(512 512) scale({echelle}) translate(-512 -512)">{contenu}</g>'


def svg(contenu, largeur=1024, hauteur=1024):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {largeur} {hauteur}" '
        f'width="{largeur}" height="{hauteur}">{contenu}</svg>\n'
    )


def ecrire(nom, contenu):
    open(f'{OUT}/{nom}.svg', 'w').write(contenu)


ICONE = carre() + dessin(A['trace'], detail=A.get('detail'))
ecrire(f'{APPLI}-logo', svg(ICONE))
ecrire(f'{APPLI}-logo-petit', svg(carre() + dessin(A['trace'], gras=1.22)))
ecrire('marque-s', svg(carre() + dessin(S)))

if A.get('eteint'):
    eteint = dessin(A['trace'], FOND_ETEINT, TRAIT_ETEINT, POINT_ETEINT, detail=A.get('detail'))
    ecrire(f'{APPLI}-deconnecte', svg(carre(FOND_ETEINT) + eteint))

if A.get('android'):
    # Couches de l'icône adaptative : le dessin est réduit pour rester dans la zone sûre
    # (cercle de 61 % du côté) quel que soit le masque du lanceur. Le fond de l'icône doit
    # rester la couleur `sdash_icon_background` de android/app/src/main/res/values/colors.xml.
    ECHELLE_ADAPTATIVE = 0.72
    # Couche avant transparente : elle sert aussi de silhouette aux icônes thématiques
    # d'Android 13+, d'où l'absence de disque de dégagement.
    ecrire(f'{APPLI}-icone-avant-plan', svg(reduit(dessin(A['trace'], degage=False), ECHELLE_ADAPTATIVE)))
    ecrire(f'{APPLI}-icone-pleine', svg(carre(arrondi=0) + reduit(dessin(A['trace']), ECHELLE_ADAPTATIVE)))


# ── Logotype : icône + nom, lettres converties en tracés (aucune police requise) ──
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
X_TEXTE = 600
s_trace, s_largeur = texte(SEMI, 's', 250, X_TEXTE, 330)
nom_trace, nom_largeur = texte(SEMI, A['nom'], 250, X_TEXTE + s_largeur + 4, 330)
devise_trace, devise_largeur = texte(MEDIUM, A['devise'], 40, X_TEXTE + 8, 420, espacement=7)
LARGEUR = round(X_TEXTE + max(s_largeur + 4 + nom_largeur, devise_largeur + 8) + 60)


def logotype(couleur_s, couleur_nom, couleur_devise):
    return svg(
        f'<svg x="40" y="40" width="480" height="480" viewBox="0 0 1024 1024">{ICONE}</svg>'
        f'<path d="{s_trace}" fill="{couleur_s}"/>'
        f'<path d="{nom_trace}" fill="{couleur_nom}"/>'
        f'<path d="{devise_trace}" fill="{couleur_devise}"/>',
        LARGEUR,
        560,
    )


ecrire(f'{APPLI}-logotype', logotype('#C2571A', '#2A1D14', '#6B5A4C'))
ecrire(f'{APPLI}-logotype-sombre', logotype('#F0A257', '#F7EEE3', '#BCA996'))
print(f'Logos « {APPLI} » générés dans {OUT}')
