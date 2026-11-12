"""Exporte les PNG et l'icône Windows à partir des SVG de `docs/logo`.

Utilisation, depuis la racine du dépôt (nécessite `pip install cairosvg pillow`) :

    python3 tools/logo/exporter.py

Fichiers produits :

    docs/logo/sphone-logo-1024.png           logo pour le README
    assets/branding/logo.png                 logo de l'en-tête de l'application
    assets/mirror/scrcpy.png                 icône de la fenêtre du téléphone
    assets/mirror/disconnected.png           image affichée quand la liaison est coupée
    windows/runner/resources/app_icon.ico    icône de l'application Windows
"""

import io

import cairosvg
from PIL import Image

LOGO = 'docs/logo/sphone-logo.svg'
PETIT = 'docs/logo/sphone-logo-petit.svg'
ETEINT = 'docs/logo/sphone-deconnecte.svg'


def rendu(svg, taille):
    png = cairosvg.svg2png(url=svg, output_width=taille, output_height=taille)
    return Image.open(io.BytesIO(png)).convert('RGBA')


rendu(LOGO, 1024).save('docs/logo/sphone-logo-1024.png', optimize=True)

rendu(LOGO, 256).save('assets/branding/logo.png', optimize=True)

# Les noms de ces deux fichiers sont imposés par scrcpy (variable SCRCPY_ICON_DIR).
rendu(LOGO, 256).save('assets/mirror/scrcpy.png', optimize=True)
rendu(ETEINT, 256).save('assets/mirror/disconnected.png', optimize=True)

# Icône Windows : une image par taille, la variante au trait renforcé pour les plus petites.
TAILLES = [16, 20, 24, 32, 40, 48, 64, 128, 256]
images = [rendu(PETIT if taille <= 32 else LOGO, taille) for taille in TAILLES]
images[-1].save(
    'windows/runner/resources/app_icon.ico',
    format='ICO',
    sizes=[(taille, taille) for taille in TAILLES],
    append_images=images[:-1],
    bitmap_format='bmp',
)
print('PNG et icône Windows exportés')
