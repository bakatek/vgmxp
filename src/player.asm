; ========================================================================
; PicoCPC PLAYTEST v3
; v2 + traduction ESC -> #EF pour que la boucle #C644 s'arrete
;
; rasm playtest.asm
; MEMORY &3FFF : LOAD"PLAYTEST.BIN",&4000 : CALL &4000
; ========================================================================

        org     #4000

KM_READ_CHAR     equ #BB09
KM_READ_KEY      equ #BB1B
TXT_OUTPUT       equ #BB5A
SCR_SET_MODE     equ #BC0E
SCR_CLEAR        equ #BC14
KL_U_ROM_ENABLE  equ #B900
KL_U_ROM_DISABLE equ #B903
KL_ROM_SELECT    equ #B90F

PICO_WAIT        equ #CEB5
PICO_PRINT       equ #CF58
PICO_LOOP        equ #C644

start:
        ld      a, 1
        call    SCR_SET_MODE
        call    SCR_CLEAR
        ld      hl, txt_t
        call    pstr
        ld      hl, fname
        call    pstr
        ld      a, 13
        call    TXT_OUTPUT

        call    rom5_on
        call    pico_start
        ld      hl, #F000
        call    PICO_PRINT

        call    hook_on
        call    PICO_LOOP
        call    hook_off

        call    rom5_off
        ld      hl, txt_end
        call    pstr
wt:     call    KM_READ_CHAR
        jr      nc, wt
        ret

; --- ESC (keycode 66) devient #EF, ce que C644 teste ---
hook_on:
        ld      hl, KM_READ_KEY
        ld      de, sav_key
        ld      bc, 3
        ldir
        ld      hl, hook_key
        ld      a, #C3
        ld      (KM_READ_KEY), a
        ld      (KM_READ_KEY+1), hl
        ret

hook_off:
        ld      hl, sav_key
        ld      de, KM_READ_KEY
        ld      bc, 3
        ldir
        ret

hook_key:
        call    sav_run
        ret     nc
        cp      66
        jr      z, hk_esc
        cp      #FC
        jr      z, hk_esc
        scf
        ret
hk_esc: ld      a, #EF
        scf
        ret

sav_run:
        ; copie des 3 octets firmware, executee ici
sav_key:
        ds      3
        ret

pico_start:
        ld      bc, #FBF2
        ld      a, #D0
        out     (c), a
        call    PICO_WAIT
        ld      a, (str_len)
        out     (c), a
        call    PICO_WAIT
        ld      hl, fname
        ld      a, (str_len)
        ld      d, a
        or      a
        ret     z
ps_lp:  ld      a, (hl)
        out     (c), a
        inc     hl
        call    PICO_WAIT
        dec     d
        jr      nz, ps_lp
        xor     a
        out     (c), a
        call    PICO_WAIT
        ret

rom5_on:
        call    KL_U_ROM_ENABLE
        ld      c, 5
        jp      KL_ROM_SELECT

rom5_off:
        jp      KL_U_ROM_DISABLE

pstr:   ld      a, (hl)
        or      a
        ret     z
        call    TXT_OUTPUT
        inc     hl
        jr      pstr

str_len:        db fname_end-fname
fname:          db "1942hi"
fname_end:      db 0

txt_t:          db "PLAYTEST v3 ESC->#EF", 13, 10
                db "ESC doit couper. Fichier: ", 0
txt_end:        db 13, 10, "Fin. Touche=quit", 13, 10, 0

        ;SAVE 'PLAYTEST.BIN',#4000,$-#4000
        SAVE 'player.BIN',#4000,$-#4000,DSK,'D:\Documents\Z80-Tyrian\tools\AceDL\media\dsk\vgmplayer.dsk'