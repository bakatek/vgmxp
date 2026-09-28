# VGM Explorer

[English](README.md) · [Français](README.fr.md) · [Español](README.es.md)

VGM file browser / player for the **Amstrad CPC 6128** with a **PicoCPC** card.

Repo: [https://github.com/bakatek/vgmxp](https://github.com/bakatek/vgmxp)

The program lists folders and `.vgm` files on the PicoCPC virtual HDD, lets you walk the tree, and starts playback through the usual PicoCPC commands (`CAT`, `CD`, `PLAY`).

## Tested hardware

- Amstrad CPC 6128  
- PicoCPC firmware **rev. 0.9**, built **27 Sep 2026** (`#7d7cbb7c`)

## Build

Assembler: **RASM**

```
rasm vgmplay.asm
```

Output: `VGMplay.BIN` (load address `#4000`).

## Run (CPC)

```
MEMORY &3FFF
LOAD"VGMplay.BIN",&4000
CALL &4000
```

Put the binary on a floppy, or load it from the PicoCPC HDD.

VGM files must be reachable the same way as with BASIC `|cat` / `|cd` / `|play` (PLAY name **without** `.vgm`).

## Controls

| Key | Action |
|-----|--------|
| Up / Down | Next line, **same column** |
| Left / Right | Other column |
| Enter / Space | Open a folder or play a `.vgm` |
| ESC | Parent folder / quit at root. During playback: stop and return to the list |
| C | Order: next or shuffle |
| B | After a track: loop the folder, or play once |
| T | Language FR / EN / ES |

**Two columns**, 18 × 2 = 36 files per page. At the bottom of a column, Down opens the **next page** (same column).

## Modes

- **NEXT + LOOP**: sequential, then restart the folder.  
- **RANDOM + LOOP**: shuffle forever.  
- **1x**: one track, then back to the list.  
- **ESC** during PLAY: stop, no skip to the next file.

Set these **before** you start a file.

## About page

Key **V** (not shown on the help lines): program version, GitHub link, PicoCPC firmware used for testing.

## Limits

- Playback uses `|PLAY`; audio is handled by the card.  
- While PLAY runs, the explorer waits for the end of the track or ESC.  
- At most 80 entries per folder.  
- No writes to the PicoCPC HDD.

## Licence

See the GitHub repository.  
PicoCPC is a separate project by [Rodrik / Neo2003](https://github.com/Neo2003/PicoCPC).

This program only uses the documented user commands (`|CAT`, `|CD`, `|PLAY`).
