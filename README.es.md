# VGM Explorer

[English](README.md) · [Français](README.fr.md) · [Español](README.es.md)

Navegador / reproductor de archivos **VGM** para **Amstrad CPC 6128** con tarjeta **PicoCPC**.

Repositorio: [https://github.com/bakatek/vgmxp](https://github.com/bakatek/vgmxp)

El programa lista carpetas y archivos `.vgm` del HDD virtual PicoCPC, permite recorrer el árbol y lanza la reproducción con las órdenes habituales de PicoCPC (`CAT`, `CD`, `PLAY`).

## Hardware probado

- Amstrad CPC 6128  
- PicoCPC firmware **rev. 0.9**, compilado el **27 sep 2026** (`#7d7cbb7c`)

## Compilación

Ensamblador: **RASM**

```
rasm vgmplay.asm
```

Salida: `VGMplay.BIN` (origen `#4000`).

## Arranque (CPC)

```
MEMORY &3FFF
LOAD"VGMplay.BIN",&4000
CALL &4000
```

Ponga el binario en un disquete o cárguelo desde el HDD PicoCPC.

Los VGM deben estar accesibles como con `|cat` / `|cd` / `|play` en BASIC (nombre **sin** `.vgm` para PLAY).

## Controles

| Tecla | Acción |
|-------|--------|
| Arriba / Abajo | Siguiente línea, **misma columna** |
| Izquierda / Derecha | La otra columna |
| Enter / Espacio | Abrir carpeta o reproducir un `.vgm` |
| ESC | Carpeta padre / salir en la raíz. En reproducción: parar y volver a la lista |
| C | Orden: siguiente o aleatorio |
| B | Tras un tema: bucle de carpeta, o un solo archivo |
| T | Idioma FR / EN / ES |

Lista en **dos columnas**, 18 × 2 = 36 archivos por página. Al final de una columna, Abajo abre la **página siguiente** (misma columna).

## Modos

- **SIGUE + BUCLE**: orden, luego reinicia la carpeta.  
- **AZAR + BUCLE**: aleatorio sin fin.  
- **1x**: un tema y vuelta a la lista.  
- **ESC** durante PLAY: para, no pasa al siguiente.

Configúrelos **antes** de lanzar un archivo.

## Página About

Tecla **V** (no aparece en la ayuda en pantalla): versión, GitHub, firmware PicoCPC de las pruebas.

## Límites

- La reproducción usa `|PLAY`; el sonido lo gestiona la tarjeta.  
- Durante PLAY, el explorador espera el final del tema o ESC.  
- Máximo 80 entradas por carpeta.  
- No escribe en el HDD PicoCPC.

## Licencia

Véase el repositorio GitHub.  
PicoCPC es un proyecto aparte de [Rodrik / Neo2003](https://github.com/Neo2003/PicoCPC).

Este programa solo usa las órdenes de usuario documentadas (`|CAT`, `|CD`, `|PLAY`).
