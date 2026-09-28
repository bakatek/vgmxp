# VGM Explorer

[English](README.md) · [Français](README.fr.md) · [Español](README.es.md)

Navigateur / lecteur de fichiers **VGM** pour **Amstrad CPC 6128** avec carte **PicoCPC**.

Dépôt : [https://github.com/bakatek/vgmxp](https://github.com/bakatek/vgmxp)

Le programme liste les dossiers et les `.vgm` de l’HDD virtuel PicoCPC, permet de se déplacer dans l’arborescence et de lancer la lecture via les commandes PicoCPC habituelles (`CAT`, `CD`, `PLAY`).

## Matériel testé

- Amstrad CPC 6128  
- PicoCPC, firmware **rev. 0.9** compilé le **27 sept. 2026** (`#7d7cbb7c`)

## Compilation

Assembleur : **RASM**

```
rasm vgmplay.asm
```

Fichier produit : `VGMxp.dsk`

## Lancement (CPC)

```
|dload,XX 
xx correspondant au fichier DSK
run"vgmxp
```

Placez le binaire sur une disquette, ou chargez-le depuis l’HDD PicoCPC.

Les VGM doivent être accessibles comme avec `|cat` / `|cd` / `|play` en BASIC (nom **sans** `.vgm` pour PLAY).

## Commandes

| Touche | Action |
|--------|--------|
| Haut / Bas | Ligne suivante, **même colonne** |
| Gauche / Droite | Autre colonne |
| Enter / Espace | Ouvrir un dossier ou jouer un `.vgm` |
| ESC | Dossier parent / quitter à la racine. En lecture : arrêter et revenir à la liste |
| C | Ordre : suivant ou hasard |
| B | Après un morceau : boucle le dossier, ou un seul fichier |
| T | Langue FR / EN / ES |
| V | Versions ou a propos

Liste en **deux colonnes**, 18 × 2 = 36 fichiers par page. En bas d’une colonne, Bas ouvre la **page suivante** (même colonne).

## Modes

- **SUITE + BOUCLE** : ordre, recommence le dossier.  
- **HASARD + BOUCLE** : enchaînement aléatoire.  
- **1x** : un morceau, puis la liste.  
- **ESC** pendant PLAY : stop, pas d’enchaînement.

À régler **avant** de lancer un fichier.

## Page About

Touche **V** (absente de l’aide à l’écran) : version, GitHub, firmware PicoCPC testé.

## Limites

- La lecture utilise `|PLAY` : le son est géré par la carte.  
- Pendant PLAY, l’explorer attend la fin du morceau ou ESC.  
- 80 entrées maximum par dossier.  
- Pas d’écriture sur l’HDD PicoCPC.

## Licence

Voir le dépôt GitHub.  
PicoCPC est un projet séparé de [Rodrik / Neo2003](https://github.com/Neo2003/PicoCPC).

Ce programme n’utilise que les commandes utilisateur documentées (`|CAT`, `|CD`, `|PLAY`).
