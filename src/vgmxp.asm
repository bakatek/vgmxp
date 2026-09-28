; ========================================================================
; PicoCPC VGM Explorer v5.36
; https://github.com/bakatek/vgmxp
; Touche V = a propos (non documentee a l'ecran)
; Z80 / RASM / CPC 6128 + PicoCPC ROM slot 5
;
; CAT  = #C8F0   CD = #CBCF   PLAY = #C5D4
;
; rasm vgmplay.asm
; MEMORY &3FFF : LOAD"VGMplay.BIN",&4000 : CALL &4000
; ========================================================================

        org     #4000

KM_READ_CHAR     equ #BB09
KM_GET_JOYSTICK  equ #BB24
TXT_OUTPUT       equ #BB5A
TXT_SET_CURSOR   equ #BB75
TXT_CUR_DISABLE  equ #BB7E
TXT_CUR_OFF      equ #BB84
TXT_SET_PEN      equ #BB90
TXT_SET_PAPER    equ #BB96
SCR_SET_MODE     equ #BC0E
SCR_CLEAR        equ #BC14
SCR_SET_INK      equ #BC32
SCR_SET_BORDER   equ #BC38
MC_WAIT_FLYBACK  equ #BD19
KL_U_ROM_ENABLE  equ #B900
KL_U_ROM_DISABLE equ #B903
KL_ROM_SELECT    equ #B90F
KL_NEW_FRAME_FLY equ #BCD7
KL_DEL_FRAME_FLY equ #BCDD
KM_TEST_KEY      equ #BB1E

LIST_ROWS        equ 18
PAGE_SIZE        equ 36
COL_W            equ 20
MAX_ITEMS        equ 80
NAME_LEN         equ 16

RSX_CAT          equ #C8F0
RSX_CD           equ #CBCF
RSX_PLAY         equ #C5D4

capture_buffer   equ #8000
CAPTURE_LIMIT    equ #8E00
type_array       equ #9000              ; 80 octets
name_pool        equ #9100              ; 80 * 16 = 1280 octets
path_buf         equ #9700
str_buf          equ #9780
pend_buf         equ #97C0

; ------------------------------------------------------------------------
start:
        di
        ld      sp, #C000
        ei
        call    init_video
        xor     a
        ld      (depth), a
        ld      (cursor), a
        ld      (scroll), a
        ld      (old_cursor), a
        ld      (path_len), a
        xor     a
        ld      (play_mode), a         ; 0=suite  1=hasard
        xor     a
        ld      (fold_mode), a         ; 0=boucle dossier  1=une fois
        xor     a
        ld      (lang), a              ; 0=FR 1=EN 2=ES
        ld      hl, path_buf
        ld      (hl), 0

browser:
        call    do_catalog
        xor     a
        ld      (cursor), a
        ld      (scroll), a
        ld      (old_cursor), a
        call    draw_ui
        call    flush_keys
        call    wait_release
        ld      a, 25
        ld      (ignore_ok), a

keyloop:
        ld      a, (ignore_ok)
        or      a
        jr      z, kl_in
        dec     a
        ld      (ignore_ok), a
kl_in:  call    read_input
        cp      252
        jp      z, do_esc
        cp      240
        jp      z, do_up
        cp      'q'
        jp      z, do_up
        cp      'Q'
        jp      z, do_up
        cp      241
        jp      z, do_down
        cp      'a'
        jp      z, do_down
        cp      'A'
        jp      z, do_down
        cp      'v'
        jp      z, do_about
        cp      'V'
        jp      z, do_about
        cp      13
        jp      z, try_ok
        cp      32
        jp      z, try_ok
        cp      'c'
        jp      z, toggle_continue
        cp      'C'
        jp      z, toggle_continue
        cp      'b'
        jp      z, toggle_fold
        cp      'B'
        jp      z, toggle_fold
        cp      't'
        jp      z, toggle_lang
        cp      'T'
        jp      z, toggle_lang
        cp      242
        jp      z, do_left
        cp      243
        jp      z, do_right
        jp      keyloop

; ------------------------------------------------------------------------
init_video:
        ld      a, 1
        call    SCR_SET_MODE
        xor     a
        ld      b, 1
        ld      c, 1
        call    SCR_SET_INK
        ld      a, 1
        ld      b, 26
        ld      c, 26
        call    SCR_SET_INK
        ld      a, 2
        ld      b, 18
        ld      c, 18
        call    SCR_SET_INK
        ld      a, 3
        ld      b, 6
        ld      c, 6
        call    SCR_SET_INK
        ld      b, 1
        ld      c, 1
        call    SCR_SET_BORDER
        call    TXT_CUR_DISABLE
        call    TXT_CUR_OFF
        xor     a
        call    TXT_SET_PAPER
        ld      a, 1
        jp      TXT_SET_PEN

; HL = adresse ROM, A = nb params, IX = bloc
; Appel direct (RST #18 plante avec cette ROM)
call_pico:
        push    af
        push    hl
        push    ix
        call    KL_U_ROM_ENABLE
        ld      c, 5
        call    KL_ROM_SELECT
        pop     ix
        pop     hl
        pop     af
        call    jphl
        push    af
        call    KL_U_ROM_DISABLE
        pop     af
        ret
jphl:   jp      (hl)

hook_esc_on:
        ld      hl, #BB1B
        ld      de, run_old_key
        ld      bc, 3
        ldir
        ld      a, #C3
        ld      (#BB1B), a
        ld      hl, hook_esc
        ld      (#BB1B+1), hl
        ret

hook_esc_off:
        ld      hl, run_old_key
        ld      de, #BB1B
        ld      bc, 3
        ldir
        ret

run_old_key:
        ds      3
        ret

hook_esc:
        call    run_old_key
        ret     nc
        cp      66
        jr      z, he_yes
        cp      #FC
        jr      z, he_yes
        scf
        ret
he_yes: ld      a, 1
        ld      (did_stop), a
        ld      a, #EF
        scf
        ret

pico_play_start:
        call    KL_U_ROM_ENABLE
        ld      c, 5
        call    KL_ROM_SELECT
        ld      bc, #FBF2
        ld      a, #D0
        out     (c), a
        call    #CEB5
        ld      a, (str_len)
        out     (c), a
        call    #CEB5
        ld      hl, str_buf
        ld      a, (str_len)
        or      a
        jr      z, pps_off
        ld      d, a
pps_lp: ld      a, (hl)
        out     (c), a
        inc     hl
        call    #CEB5
        dec     d
        jr      nz, pps_lp
        xor     a
        out     (c), a
        call    #CEB5
pps_off:
        call    KL_U_ROM_DISABLE
        ret

pico_play_stop:
        call    KL_U_ROM_ENABLE
        ld      c, 5
        call    KL_ROM_SELECT
        ld      bc, #FBF2
        ld      a, #D3
        out     (c), a
        call    #CEB5
        call    KL_U_ROM_DISABLE
        ret

; PLAY teste KM_READ_KEY (#BB1B) pour #EF. On traduit ESC (66) -> #EF
KM_READ_KEY      equ #BB1B

arm_esc_key:
        di
        ld      hl, KM_READ_KEY
        ld      de, sav_key
        ld      bc, hook_key
        call    patch_jp
        ei
        ret

disarm_esc_key:
        di
        ld      hl, KM_READ_KEY
        ld      de, sav_key
        call    unpatch
        ei
        ret

hook_key:
        ld      a, 66
        call    KM_TEST_KEY
        jr      nc, hk_orig
        ld      a, #EF
        scf
        ret
hk_orig:
        ; execute le 3 octets sauves (souvent JP xxxx)
        jp      sav_key_run
sav_key_run:
        ds      3
        ret

arm_play_gfx:
        xor     a
        ld      (gfx_on), a
        ld      (gfx_deb), a
        call    stars_init
        ld      de, fly_block
        ld      hl, play_vbl
        jp      KL_NEW_FRAME_FLY

disarm_play_gfx:
        ld      hl, fly_block
        jp      KL_DEL_FRAME_FLY

; Ecrit DIRECTEMENT en RAM ecran (#C000), sans firmware (ROM 5 pagee)
play_vbl:
        push    af
        push    bc
        push    de
        push    hl
        ; G (touche 52) bascule anim / texte
        ld      a, 52
        call    KM_TEST_KEY
        jr      nc, pv_up
        ld      a, (gfx_deb)
        or      a
        jr      nz, pv_gfx
        ld      a, 1
        ld      (gfx_deb), a
        ld      a, (gfx_on)
        xor     1
        ld      (gfx_on), a
        jr      pv_gfx
pv_up:  xor     a
        ld      (gfx_deb), a
pv_gfx: ld      a, (gfx_on)
        or      a
        jr      z, pv_out
        ld      hl, stars
        ld      b, 16
pv_lp:  push    bc
        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        xor     a
        ld      (de), a
        ld      a, e
        add     a, 80
        ld      e, a
        ld      a, d
        adc     a, 0
        ld      d, a
        cp      #C0
        jr      nc, pv_ok
        call    star_rnd
        ld      e, a
        call    star_rnd
        and     #3F
        or      #C0
        ld      d, a
pv_ok:  ld      a, #F0
        ld      (de), a
        ld      (hl), d
        dec     hl
        ld      (hl), e
        inc     hl
        inc     hl
        pop     bc
        djnz    pv_lp
pv_out: pop     hl
        pop     de
        pop     bc
        pop     af
        ret

stars_init:
        ld      hl, stars
        ld      b, 16
si_lp:  push    bc
        call    star_rnd
        ld      (hl), a
        inc     hl
        call    star_rnd
        and     #3F
        or      #C0
        ld      (hl), a
        inc     hl
        pop     bc
        djnz    si_lp
        ret

star_rnd:
        ld      a, (rnd_s)
        add     a, 45
        rrca
        xor     #5A
        ld      (rnd_s), a
        ret

; ------------------------------------------------------------------------
do_catalog:
        xor     a
        ld      (total), a
        ld      (page_cnt), a
        ld      (pend_len), a
        ld      hl, capture_buffer
        ld      (cap_ptr), hl
        ld      (hl), 0

        di
        ld      hl, TXT_OUTPUT
        ld      de, sav_out
        ld      bc, hook_txt
        call    patch_jp
        ld      hl, #BB06              ; KM_WAIT_CHAR
        ld      de, sav_wait
        ld      bc, hook_wait
        call    patch_jp
        ei

        xor     a
        ld      hl, RSX_CAT
        call    call_pico

        di
        ld      hl, TXT_OUTPUT
        ld      de, sav_out
        call    unpatch
        ld      hl, #BB06
        ld      de, sav_wait
        call    unpatch
        ei

        ld      hl, (cap_ptr)
        ld      (hl), 0
        jp      parse_buf

patch_jp:
        push    bc
        ld      a, (hl)
        ld      (de), a
        inc     hl
        inc     de
        ld      a, (hl)
        ld      (de), a
        inc     hl
        inc     de
        ld      a, (hl)
        ld      (de), a
        dec     hl
        dec     hl
        pop     bc
        ld      a, #C3
        ld      (hl), a
        inc     hl
        ld      a, c
        ld      (hl), a
        inc     hl
        ld      a, b
        ld      (hl), a
        ret

unpatch:
        ld      a, (de)
        ld      (hl), a
        inc     hl
        inc     de
        ld      a, (de)
        ld      (hl), a
        inc     hl
        inc     de
        ld      a, (de)
        ld      (hl), a
        ret

hook_txt:
        push    af
        push    hl
        push    de
        cp      13
        jr      z, ht_put
        cp      10
        jr      z, ht_cr
        cp      9
        jr      z, ht_sp
        cp      32
        jr      c, ht_end
ht_put: ld      hl, (cap_ptr)
        ld      de, CAPTURE_LIMIT
        or      a
        sbc     hl, de
        jr      nc, ht_end
        ld      hl, (cap_ptr)
        ld      (hl), a
        inc     hl
        ld      (cap_ptr), hl
        jr      ht_end
ht_cr:  ld      a, 32
        jr      ht_put
ht_sp:  ld      a, 32
        jr      ht_put
ht_end: pop     de
        pop     hl
        pop     af
        ret

hook_wait:
        ld      a, (page_cnt)
        inc     a
        ld      (page_cnt), a
        cp      40
        jr      nc, hw_esc
        ld      a, 32
        scf
        ret
hw_esc: ld      a, 252
        scf
        ret

; ========================================================================
; PARSEUR
; Tokens PicoCPC typiques :
;   (VGM)            -> dossier
;   AcidTrac.vgm     -> fichier
;   02Spice  .vgm    -> nom + extension separes
;   164K             -> taille, ignoree
; ========================================================================
parse_buf:
        xor     a
        ld      (total), a
        ld      (pend_len), a
        ld      (saw_vgm), a

        ld      a, (depth)
        or      a
        jr      z, pb_dirs
        ld      hl, str_dotdot
        ld      a, 2
        call    store_item

; --- Passe 1 : tout ce qui est entre ( ) = repertoire ---
pb_dirs:
        ld      hl, capture_buffer
pd_lp:  ld      a, (hl)
        or      a
        jr      z, pb_go
        cp      '('
        jr      nz, pd_nx
        inc     hl
        ld      de, str_buf
        ld      b, 0
pd_cp:  ld      a, (hl)
        or      a
        jr      z, pd_st
        cp      ')'
        jr      z, pd_st
        cp      13
        jr      z, pd_st
        cp      32
        jr      z, pd_st
        ld      (de), a
        inc     de
        inc     hl
        inc     b
        ld      a, b
        cp      NAME_LEN-1
        jr      c, pd_cp
pd_st:  xor     a
        ld      (de), a
        ld      a, b
        cp      1
        jr      c, pd_nx
        push    hl
        ld      hl, str_buf
        ld      a, 1
        call    store_item
        pop     hl
pd_nx:  inc     hl
        jr      pd_lp

pb_go:  ld      hl, capture_buffer

pb_lp:  call    skip_sep
        ld      a, (hl)
        or      a
        jp      z, pb_flush

        ld      (tok_ptr), hl
        call    scan_tok               ; HL = apres token, tok_len rempli
        push    hl

        ld      hl, (tok_ptr)
        call    tok_is_drive
        jp      z, pb_pop

        ld      hl, (tok_ptr)
        ld      a, (hl)
        cp      '('
        jp      z, pb_pop              ; deja pris en passe 1
        cp      ')'
        jp      z, pb_pop

pb_notdir:
        ld      hl, (tok_ptr)
        call    tok_is_size
        jp      z, pb_pop
        ld      hl, (tok_ptr)
        call    tok_is_num
        jp      z, pb_pop

        ld      hl, (tok_ptr)
        call    tok_is_ext
        jr      nz, pb_notext
        ; token = ".vgm" -> fichier = pending
        ld      a, (pend_len)
        or      a
        jr      z, pb_pop
        ld      a, 1
        ld      (saw_vgm), a
        call    pend_add_vgm
        ld      hl, pend_buf
        xor     a
        call    store_item
        xor     a
        ld      (pend_len), a
        jp      pb_pop

pb_notext:
        ld      hl, (tok_ptr)
        call    tok_has_vgm
        jr      nz, pb_plain
        ; mot se termine par .vgm
        ld      a, 1
        ld      (saw_vgm), a
        ld      hl, (tok_ptr)
        xor     a
        call    store_tok
        xor     a
        ld      (pend_len), a
        jp      pb_pop

pb_plain:
        ; nom sans extension -> pending
        call    save_pending

pb_pop: pop     hl
        jp      pb_lp

pb_flush:
        ; ne pas transformer un nom isolé (souvent un DIR) en fichier
        ret

; HL in = pos, saute espaces
skip_sep:
        ld      a, (hl)
        or      a
        ret     z
        cp      32
        ret     nz
        inc     hl
        jr      skip_sep

; HL = debut token -> avance HL a la fin, tok_len = longueur
scan_tok:
        xor     a
        ld      (tok_len), a
st_lp:  ld      a, (hl)
        or      a
        ret     z
        cp      32
        ret     z
        inc     hl
        ld      a, (tok_len)
        inc     a
        ld      (tok_len), a
        jr      st_lp

tok_is_drive:
        ld      a, (hl)
        call    upcase
        cp      'D'
        ret     nz
        inc     hl
        ld      a, (hl)
        call    upcase
        cp      'R'
        ret     nz
        xor     a
        ret

; taille : chiffres puis K (ex 164K, 8K)
tok_is_size:
        ld      a, (tok_len)
        cp      2
        ret     c
        ld      b, a
        dec     b                      ; tout sauf dernier
ts_d:   ld      a, (hl)
        cp      '0'
        ret     c
        cp      '9'+1
        jr      nc, ts_no
        inc     hl
        djnz    ts_d
        ld      a, (hl)
        call    upcase
        cp      'K'
        ret     nz
        xor     a
        ret
ts_no:  or      1
        ret

; token uniquement numerique (fragment de taille)
tok_is_num:
        ld      a, (tok_len)
        or      a
        ret     z
        ld      b, a
tn_lp:  ld      a, (hl)
        cp      '0'
        ret     c
        cp      '9'+1
        jr      nc, tn_no
        inc     hl
        djnz    tn_lp
        xor     a
        ret
tn_no:  or      1
        ret

; token entier = ".vgm"
tok_is_ext:
        ld      a, (tok_len)
        cp      4
        ret     nz
        ld      a, (hl)
        cp      '.'
        ret     nz
        inc     hl
        ld      a, (hl)
        call    upcase
        cp      'V'
        ret     nz
        inc     hl
        ld      a, (hl)
        call    upcase
        cp      'G'
        ret     nz
        inc     hl
        ld      a, (hl)
        call    upcase
        cp      'M'
        ret     nz
        xor     a
        ret

; se termine par .vgm
tok_has_vgm:
        ld      a, (tok_len)
        cp      5
        ret     c
        ld      e, a
        ld      d, 0
        add     hl, de
        dec     hl
        ld      a, (hl)
        call    upcase
        cp      'M'
        ret     nz
        dec     hl
        ld      a, (hl)
        call    upcase
        cp      'G'
        ret     nz
        dec     hl
        ld      a, (hl)
        call    upcase
        cp      'V'
        ret     nz
        dec     hl
        ld      a, (hl)
        cp      '.'
        ret     nz
        xor     a
        ret

add_dir_tok:
        ld      hl, (tok_ptr)
        inc     hl                     ; saute (
        ld      de, str_buf
        ld      b, 0
ad_lp:  ld      a, (hl)
        or      a
        jr      z, ad_dn
        cp      ')'
        jr      z, ad_dn
        cp      32
        jr      z, ad_dn
        ld      (de), a
        inc     de
        inc     hl
        inc     b
        ld      a, b
        cp      NAME_LEN-1
        jr      c, ad_lp
ad_dn:  xor     a
        ld      (de), a
        ld      hl, str_buf
        ld      a, 1
        jp      store_item

; Ajoute .vgm a pend_buf si absent
pend_add_vgm:
        ld      hl, pend_buf
        call    name_has_ext
        ret     z
        ld      hl, pend_buf
        ld      a, (pend_len)
        ld      e, a
        ld      d, 0
        add     hl, de
        ld      (hl), '.'
        inc     hl
        ld      (hl), 'v'
        inc     hl
        ld      (hl), 'g'
        inc     hl
        ld      (hl), 'm'
        inc     hl
        ld      (hl), 0
        ld      a, (pend_len)
        add     a, 4
        ld      (pend_len), a
        ret

save_pending:
        ld      hl, (tok_ptr)
        ld      de, pend_buf
        ld      a, (tok_len)
        cp      NAME_LEN
        jr      c, sp_ok
        ld      a, NAME_LEN-1
sp_ok:  ld      (pend_len), a
        ld      b, a
        or      a
        ret     z
sp_lp:  ld      a, (hl)
        ld      (de), a
        inc     hl
        inc     de
        djnz    sp_lp
        xor     a
        ld      (de), a
        ret

; Copie un token de longueur tok_len (pas zero-termine)
store_tok:
        ld      a, (tok_len)
        ld      (copy_len), a
        jr      store_common

; A = type, HL = nom zero-termine
store_item:
        push    hl
        ld      b, 0
si_cnt: ld      a, (hl)
        or      a
        jr      z, si_got
        inc     hl
        inc     b
        ld      a, b
        cp      NAME_LEN-1
        jr      c, si_cnt
si_got: ld      a, b
        ld      (copy_len), a
        pop     hl

store_common:
        push    af
        ld      a, (total)
        cp      MAX_ITEMS
        jr      nc, si_abort
        push    hl
        ld      l, a
        ld      h, 0
        ld      de, type_array
        add     hl, de
        pop     de
        pop     af
        ld      (hl), a
        push    de
        ld      a, (total)
        ld      l, a
        ld      h, 0
        add     hl, hl
        add     hl, hl
        add     hl, hl
        add     hl, hl
        ld      bc, name_pool
        add     hl, bc
        pop     de
        ld      a, (copy_len)
        or      a
        jr      z, si_z
        cp      NAME_LEN
        jr      c, si_ok
        ld      a, NAME_LEN-1
si_ok:  ld      b, a
si_cp:  ld      a, (de)
        cp      32
        jr      z, si_z
        or      a
        jr      z, si_z
        ld      (hl), a
        inc     hl
        inc     de
        djnz    si_cp
si_z:   ld      (hl), 0
        ld      a, (total)
        inc     a
        ld      (total), a
        ret
si_abort:
        pop     af
        ret

upcase:
        cp      'a'
        ret     c
        cp      'z'+1
        ret     nc
        sub     32
        ret

; ========================================================================
draw_ui:
        call    SCR_CLEAR
        xor     a
        call    TXT_SET_PAPER
        ld      a, 1
        call    TXT_SET_PEN

        ld      h, 5
        ld      l, 1
        ld      de, txt_title
        call    at_str

        ld      h, 1
        ld      l, 2
        call    TXT_SET_CURSOR
        ld      hl, txt_root
        call    print_str
        ld      a, (path_len)
        or      a
        jr      z, du_mode
        ld      hl, path_buf
        call    print_str

du_mode:
        ld      h, 22
        ld      l, 2
        call    TXT_SET_CURSOR
        ld      a, (play_mode)
        ld      hl, tab_suite
        or      a
        jr      z, du_m1
        ld      hl, tab_hasard
du_m1:  call    print_lang
        ld      a, ' '
        call    TXT_OUTPUT
        ld      a, (fold_mode)
        ld      hl, tab_boucle
        or      a
        jr      z, du_m2
        ld      hl, tab_1x
du_m2:  call    print_lang

du_body:
        ld      a, (total)
        or      a
        jr      nz, du_lst
        ld      h, 2
        ld      l, 10
        ld      de, txt_empty
        call    at_str
        jp      du_foot

du_lst: ld      b, 0
du_row: ld      a, b
        cp      LIST_ROWS
        jp      z, du_foot
        ld      a, (scroll)
        add     a, b
        ld      c, a
        ld      a, (total)
        cp      c
        jr      z, du_rcol
        jr      c, du_rcol
        push    bc
        xor     a
        ld      (cell_col), a
        call    draw_cell
        pop     bc
du_rcol:
        ld      a, (scroll)
        add     a, b
        add     a, LIST_ROWS
        ld      c, a
        ld      a, (total)
        cp      c
        jr      z, du_nxt
        jr      c, du_nxt
        push    bc
        ld      a, 1
        ld      (cell_col), a
        call    draw_cell
        pop     bc
du_nxt: inc     b
        jp      du_row

du_foot:
        xor     a
        call    TXT_SET_PAPER
        ld      a, 1
        call    TXT_SET_PEN
        call    draw_count
        ld      h, 1
        ld      l, 24
        call    TXT_SET_CURSOR
        ld      hl, tab_l1
        call    print_lang
        ld      h, 1
        ld      l, 25
        call    TXT_SET_CURSOR
        ld      hl, tab_l2
        jp      print_lang

draw_count:
        ld      h, 1
        ld      l, 23
        call    TXT_SET_CURSOR
        ld      a, (cursor)
        inc     a
        call    print_num
        ld      a, '/'
        call    TXT_OUTPUT
        ld      a, (total)
        jp      print_num


; C = index fichier
draw_cell:
        ld      a, (total)
        cp      c
        ret     z
        ret     c
        ld      a, (scroll)
        ld      b, a
        ld      a, c
        sub     b
        ld      b, a                   ; offset dans la page 0..35
        cp      LIST_ROWS
        jr      c, dc_left
        sub     LIST_ROWS
        ld      b, a
        ld      a, 1
        jr      dc_col
dc_left:xor     a
dc_col: ld      (cell_col), a
        ; B = ligne 0..17, C = index
        push    bc
        ld      a, (cell_col)
        or      a
        ld      h, 1
        jr      z, dc_h
        ld      h, 21
dc_h:   ld      a, b
        add     a, 4
        ld      l, a
        call    TXT_SET_CURSOR
        ld      b, COL_W
dc_cl:  ld      a, 32
        call    TXT_OUTPUT
        djnz    dc_cl
        pop     bc
        push    bc
        ld      a, (cell_col)
        or      a
        ld      h, 1
        jr      z, dc_h2
        ld      h, 21
dc_h2:  ld      a, b
        add     a, 4
        ld      l, a
        call    TXT_SET_CURSOR
        pop     bc

        ld      a, (cursor)
        cp      c
        jr      nz, dc_ns
        push    bc
        ld      a, 1
        call    TXT_SET_PAPER
        xor     a
        call    TXT_SET_PEN
        pop     bc
        ld      a, '>'
        call    TXT_OUTPUT
        jr      dc_nm
dc_ns:  push    bc
        xor     a
        call    TXT_SET_PAPER
        ld      a, 1
        call    TXT_SET_PEN
        pop     bc
        ld      a, ' '
        call    TXT_OUTPUT
dc_nm:  push    bc
        ld      a, c
        call    get_type
        or      a
        jr      z, dc_fn
        ld      a, 2
        call    TXT_SET_PEN
dc_fn:  ld      a, c
        call    get_name
        ld      b, 14
        call    print_n
        pop     bc
        push    bc
        ld      a, c
        call    get_name
        call    name_has_ext
        jr      z, dc_tag
        ld      a, c
        call    get_type
        or      a
        jr      nz, dc_tag
        ld      hl, txt_dotvgm
        call    print_str
dc_tag: pop     bc
        push    bc
        ld      a, c
        call    get_name
        call    name_has_ext
        jr      z, dc_rs
        ld      a, c
        call    get_type
        or      a
        jr      z, dc_rs
        cp      2
        ld      hl, txt_par
        jr      z, dc_sx
        ld      hl, txt_dir
dc_sx:  call    print_str
dc_rs:  xor     a
        call    TXT_SET_PAPER
        ld      a, 1
        call    TXT_SET_PEN
        pop     bc
        ret

draw_one_line:
        jp      draw_cell

update_cursor:
        ld      a, (old_cursor)
        ld      c, a
        call    draw_cell
        ld      a, (cursor)
        ld      (old_cursor), a
        ld      c, a
        call    draw_cell
        jp      draw_count

; Aligne scroll sur page de 36
fit_page:
        ld      a, (scroll)
        ld      (old_scroll), a
        ld      a, (cursor)
        ld      b, 0
fp_lp:  cp      PAGE_SIZE
        jr      c, fp_ok
        sub     PAGE_SIZE
        inc     b
        jr      fp_lp
fp_ok:  ld      a, b
        add     a, a                    ; *2
        add     a, a                    ; *4
        ld      c, a
        add     a, a                    ; *8
        add     a, a                    ; *16
        add     a, a                    ; *32
        add     a, c                    ; *36
        ld      (scroll), a
        ld      b, a
        ld      a, (old_scroll)
        cp      b
        ret                             ; Z si meme page

at_str: push    de
        call    TXT_SET_CURSOR
        pop     hl
print_str:
        ld      a, (hl)
        or      a
        ret     z
        call    TXT_OUTPUT
        inc     hl
        jr      print_str

print_n:
        ld      a, (hl)
        or      a
        ret     z
        call    TXT_OUTPUT
        inc     hl
        djnz    print_n
        ret

get_name:
        ld      l, a
        ld      h, 0
        add     hl, hl
        add     hl, hl
        add     hl, hl
        add     hl, hl
        ld      de, name_pool
        add     hl, de
        ret

get_type:
        ld      e, a
        ld      d, 0
        ld      hl, type_array
        add     hl, de
        ld      a, (hl)
        ret

print_num:
        ld      l, a
        ld      h, 0
        ld      d, 0
        ld      bc, 100
        call    pn1
        ld      bc, 10
        call    pn1
        ld      a, l
        add     a, '0'
        jp      TXT_OUTPUT
pn1:    ld      a, '0'-1
pn2:    inc     a
        or      a
        sbc     hl, bc
        jr      nc, pn2
        add     hl, bc
        cp      '0'
        jr      nz, pn3
        ld      e, a
        ld      a, d
        or      a
        ld      a, e
        ret     z
pn3:    ld      d, 1
        jp      TXT_OUTPUT

flush_keys:
        call    KM_READ_CHAR
        jr      c, flush_keys
        ret

; Attend que ENT / ESP / ESC / fire soient relaches
wait_release:
        ld      a, 18                  ; RETURN
        call    KM_TEST_KEY
        jr      c, wait_release
        ld      a, 47                  ; SPACE
        call    KM_TEST_KEY
        jr      c, wait_release
        ld      a, 66                  ; ESC
        call    KM_TEST_KEY
        jr      c, wait_release
        call    KM_GET_JOYSTICK
        ld      a, h
        and     #30
        jr      nz, wait_release
        ret

try_ok:
        ld      a, (ignore_ok)
        or      a
        jp      nz, keyloop
        jp      do_ok

read_input:
        call    KM_READ_CHAR
        jr      nc, ri_nokey
        cp      13
        jr      z, ri_okkey
        cp      32
        jr      z, ri_okkey
        ret
ri_okkey:
        ld      a, (ignore_ok)
        or      a
        jr      nz, read_input
        ld      a, 13
        ret
ri_nokey:
        ld      a, (ignore_ok)
        or      a
        jr      z, ri_joy
        dec     a
        ld      (ignore_ok), a
ri_joy: call    KM_GET_JOYSTICK
        ld      a, h
        and     #3F
        jr      z, ri_idle
        ld      b, 6
ri_d:   push    af
        push    bc
        call    MC_WAIT_FLYBACK
        pop     bc
        pop     af
        djnz    ri_d
        call    KM_GET_JOYSTICK
        ld      a, h
        bit     0, a
        jr      nz, ri_u
        bit     1, a
        jr      nz, ri_n
        bit     2, a
        jr      nz, ri_l
        bit     3, a
        jr      nz, ri_r
        bit     4, a
        jr      nz, ri_o
        bit     5, a
        jr      nz, ri_esc
        jr      read_input
ri_u:   ld      a, 240
        ret
ri_n:   ld      a, 241
        ret
ri_l:   ld      a, 242
        ret
ri_r:   ld      a, 243
        ret
ri_o:   ld      a, (ignore_ok)
        or      a
        jr      nz, read_input
        ld      a, 13
        ret
ri_esc: ld      a, 252
        ret
ri_idle:
        call    MC_WAIT_FLYBACK
        jr      read_input

; Petite barre de pixels sur la ligne 3 si G actif
gfx_tick:
        ld      a, (gfx_on)
        or      a
        ret     z
        ld      a, (gfx_x)
        ld      h, a
        ld      l, 3
        call    TXT_SET_CURSOR
        ld      a, 32
        call    TXT_OUTPUT
        ld      a, (gfx_x)
        inc     a
        cp      40
        jr      c, gx_ok
        ld      a, 1
gx_ok:  ld      (gfx_x), a
        ld      h, a
        ld      l, 3
        call    TXT_SET_CURSOR
        ld      a, 2
        call    TXT_SET_PEN
        ld      a, '*'
        call    TXT_OUTPUT
        ld      a, 1
        jp      TXT_SET_PEN

do_up:
        ld      a, (total)
        or      a
        jp      z, keyloop
        ld      a, (cursor)
        or      a
        jp      z, keyloop
        ld      (old_cursor), a
        call    col_offset
        or      a
        jr      z, up_page
        cp      LIST_ROWS
        jr      z, up_page
        ld      a, (cursor)
        dec     a
        ld      (cursor), a
        jr      nav_fit
up_page:
        ld      a, (cursor)
        sub     19
        jp      c, keyloop
        ld      (cursor), a
        jr      nav_fit

do_down:
        ld      a, (total)
        or      a
        jp      z, keyloop
        ld      a, (cursor)
        ld      (old_cursor), a
        call    col_offset
        cp      LIST_ROWS-1
        jr      z, dn_page
        cp      PAGE_SIZE-1
        jr      z, dn_page
        ld      a, (cursor)
        inc     a
        ld      b, a
        ld      a, (total)
        cp      b
        jp      z, keyloop
        jp      c, keyloop
        ld      a, b
        ld      (cursor), a
        jr      nav_fit
dn_page:
        ld      a, (cursor)
        add     a, 19
        ld      b, a
        ld      a, (total)
        cp      b
        jp      z, keyloop
        jp      c, keyloop
        ld      a, b
        ld      (cursor), a
nav_fit:
        call    fit_page
        jr      nz, nav_redraw
        call    update_cursor
        jp      keyloop

col_offset:
        ld      a, (cursor)
        ld      b, a
        ld      a, (scroll)
        ld      c, a
        ld      a, b
        sub     c
        ret

do_left:
        ld      a, (cursor)
        cp      LIST_ROWS
        jp      c, keyloop
        ld      (old_cursor), a
        sub     LIST_ROWS
        ld      (cursor), a
        call    fit_page
        jr      nz, nav_redraw
        call    update_cursor
        jp      keyloop

do_right:
        ld      a, (total)
        ld      b, a
        ld      a, (cursor)
        ld      (old_cursor), a
        add     a, LIST_ROWS
        cp      b
        jp      nc, keyloop
        ld      (cursor), a
        call    fit_page
        jr      nz, nav_redraw
        call    update_cursor
        jp      keyloop

nav_redraw:
        call    draw_ui
        jp      keyloop

do_esc:
do_quit:
        call    KL_U_ROM_DISABLE
        call    SCR_CLEAR
        ret

do_ok:
        ld      a, (total)
        or      a
        jp      z, keyloop
        ld      a, (cursor)
        call    get_type
        cp      2
        jr      z, ok_up
        cp      1
        jr      z, ok_dir
        ld      a, (cursor)
        call    get_name
        call    name_has_ext
        jr      z, ok_play             ; a un .vgm -> fichier
        jr      ok_dir                 ; sinon -> dossier

ok_up:  call    cd_up
        jp      browser

ok_dir: ld      a, (cursor)
        call    copy_name_to_str
        ld      a, (str_len)
        or      a
        jp      z, keyloop
        ld      a, 1
        ld      ix, param_blk
        ld      hl, RSX_CD
        call    call_pico
        ld      a, (depth)
        inc     a
        ld      (depth), a
        call    path_push
        jp      browser

ok_play:
        ld      a, (cursor)
        call    copy_name_to_str
        call    strip_vgm
        ld      a, (str_len)
        or      a
        jp      z, keyloop
        call    play_current
        call    KL_U_ROM_DISABLE
        jp      browser

play_current:
        call    draw_play_screen
        xor     a
        ld      (did_stop), a
        call    pico_play_start
        call    KL_U_ROM_ENABLE
        ld      c, 5
        call    KL_ROM_SELECT
        ld      hl, #F000
        call    #CF58
        call    hook_esc_on
        call    #C644
        call    hook_esc_off
        call    KL_U_ROM_DISABLE
        call    init_video
        ld      a, (did_stop)
        or      a
        ret     nz
        ld      a, (fold_mode)
        or      a
        ret     nz                     ; 1x = stop apres ce fichier
        ld      a, (play_mode)
        or      a
        jr      z, play_next           ; suite
        call    random_next
        jr      play_go
play_next:
        ld      a, (cursor)
        inc     a
        ld      b, a
        ld      a, (total)
        cp      b
        jr      nz, pn_ok
        xor     a                      ; recommence la liste
        ld      b, a
pn_ok:  ld      a, b
        ld      (cursor), a
        call    get_type
        cp      2
        jr      z, play_next           ; saute uniquement ..
play_go:
        ld      a, (cursor)
        call    copy_name_to_str
        call    strip_vgm
        ld      a, (str_len)
        or      a
        ret     z
        jr      play_current

random_next:
        ld      a, (cursor)
        add     a, 17
        ld      b, a
        ld      a, (total)
        or      a
        ret     z
        ld      c, a
rnd_lp: ld      a, b
        cp      c
        jr      c, rnd_ok
        sub     c
        ld      b, a
        jr      rnd_lp
rnd_ok: ld      a, b
        ld      (cursor), a
        call    get_type
        cp      2
        jr      z, random_next
        ret

draw_play_screen:
        call    SCR_CLEAR
        ld      h, 8
        ld      l, 6
        ld      de, txt_playing
        call    at_str
        ld      h, 4
        ld      l, 10
        call    TXT_SET_CURSOR
        ld      hl, str_buf
        call    print_str
        ld      h, 4
        ld      l, 14
        ld      de, txt_esc
        call    at_str
        ld      h, 4
        ld      l, 16
        ld      de, txt_modeinfo
        call    at_str
        ld      a, 13
        call    TXT_OUTPUT
        ret

cd_up:
        ld      a, (depth)
        or      a
        ret     z
        ld      hl, str_buf
        ld      (hl), '.'
        inc     hl
        ld      (hl), '.'
        inc     hl
        ld      (hl), 0
        ld      a, 2
        ld      (str_len), a
        ld      a, 1
        ld      ix, param_blk
        ld      hl, RSX_CD
        call    call_pico
        ld      a, (depth)
        dec     a
        ld      (depth), a
        jp      path_pop

copy_name_to_str:
        call    get_name
        ld      de, str_buf
        ld      b, 0
cn_lp:  ld      a, (hl)
        ld      (de), a
        or      a
        jr      z, cn_dn
        inc     hl
        inc     de
        inc     b
        ld      a, b
        cp      NAME_LEN
        jr      c, cn_lp
        xor     a
        ld      (de), a
cn_dn:  ld      a, b
        ld      (str_len), a
        ret

strip_vgm:
        ld      a, (str_len)
        cp      5
        ret     c
        ld      hl, str_buf
        ld      e, a
        ld      d, 0
        add     hl, de
        dec     hl
        ld      a, (hl)
        call    upcase
        cp      'M'
        ret     nz
        dec     hl
        ld      a, (hl)
        call    upcase
        cp      'G'
        ret     nz
        dec     hl
        ld      a, (hl)
        call    upcase
        cp      'V'
        ret     nz
        dec     hl
        ld      a, (hl)
        cp      '.'
        ret     nz
        ld      (hl), 0
        ld      a, (str_len)
        sub     4
        ld      (str_len), a
        ret

path_push:
        ld      a, (path_len)
        cp      40
        ret     nc
        ld      hl, path_buf
        ld      e, a
        ld      d, 0
        add     hl, de
        ld      (hl), '/'
        inc     hl
        ld      de, str_buf
        ld      b, 14
pp1:    ld      a, (de)
        or      a
        jr      z, pp2
        cp      '.'
        jr      z, pp2
        ld      (hl), a
        inc     hl
        inc     de
        djnz    pp1
pp2:    ld      (hl), 0
        ld      de, path_buf
        or      a
        sbc     hl, de
        ld      a, l
        ld      (path_len), a
        ret

path_pop:
        ld      a, (path_len)
        or      a
        ret     z
        ld      hl, path_buf
        ld      e, a
        ld      d, 0
        add     hl, de
ppop:   ld      a, (path_len)
        or      a
        jr      z, ppz
        dec     hl
        dec     a
        ld      (path_len), a
        ld      a, (hl)
        cp      '/'
        jr      nz, ppop
        ld      (hl), 0
        ret
ppz:    ld      (hl), 0
        ret

toggle_continue:
        ld      a, (play_mode)
        xor     1
        ld      (play_mode), a
        call    draw_ui
        jp      keyloop

toggle_fold:
        ld      a, (fold_mode)
        xor     1
        ld      (fold_mode), a
        call    draw_ui
        jp      keyloop

toggle_lang:
        ld      a, (lang)
        inc     a
        cp      3
        jr      c, tl_ok
        xor     a
tl_ok:  ld      (lang), a
        call    draw_ui
        jp      keyloop

do_about:
        call    SCR_CLEAR
        xor     a
        call    TXT_SET_PAPER
        ld      a, 1
        call    TXT_SET_PEN
        ld      h, 2
        ld      l, 4
        call    TXT_SET_CURSOR
        ld      hl, tab_ab1
        call    print_lang
        ld      h, 2
        ld      l, 6
        call    TXT_SET_CURSOR
        ld      hl, ab_url
        call    print_str
        ld      h, 2
        ld      l, 8
        call    TXT_SET_CURSOR
        ld      hl, tab_ab3
        call    print_lang
        ld      h, 2
        ld      l, 10
        call    TXT_SET_CURSOR
        ld      hl, tab_ab4
        call    print_lang
        ld      h, 2
        ld      l, 12
        call    TXT_SET_CURSOR
        ld      hl, ab_fw
        call    print_str
        ld      h, 2
        ld      l, 14
        call    TXT_SET_CURSOR
        ld      hl, ab_date
        call    print_str
        ld      h, 2
        ld      l, 20
        call    TXT_SET_CURSOR
        ld      hl, tab_ab7
        call    print_lang
ab_w:   call    KM_READ_CHAR
        jr      nc, ab_w
        call    draw_ui
        jp      keyloop

toggle_gfx:
        ld      a, (gfx_on)
        xor     1
        ld      (gfx_on), a
        call    draw_ui
        jp      keyloop

; HL = table de 3 pointeurs (FR,EN,ES)
print_lang:
        ld      a, (lang)
        add     a, a
        ld      e, a
        ld      d, 0
        add     hl, de
        ld      a, (hl)
        inc     hl
        ld      h, (hl)
        ld      l, a
        jp      print_str

do_demo:
        call    SCR_CLEAR
        ld      a, 2
        call    TXT_SET_PEN
        ld      h, 8
        ld      l, 2
        ld      de, txt_demo
        call    at_str
        call    draw_pyramid
        call    draw_tower
        ld      a, 1
        call    TXT_SET_PEN
        ld      h, 2
        ld      l, 24
        ld      de, txt_demofoot
        call    at_str
dm_w:   call    KM_READ_CHAR
        jr      nc, dm_w
        call    draw_ui
        jp      keyloop

; Pyramide (lignes / et \)
draw_pyramid:
        ld      d, 12                  ; ligne
        ld      e, 6                  ; largeur
dp_row: ld      a, 20
        sub     e
        srl     a
        add     a, 2
        ld      h, a
        ld      l, d
        call    TXT_SET_CURSOR
        ld      a, '/'
        call    TXT_OUTPUT
        ld      b, e
        dec     b
        dec     b
        jr      z, dp_endr
        ld      a, 2
        call    TXT_SET_PEN
dp_sp:  ld      a, ' '
        ; remplissage
        push    bc
        ld      a, 138                 ; bloc
        call    TXT_OUTPUT
        pop     bc
        djnz    dp_sp
        ld      a, 2
        call    TXT_SET_PEN
dp_endr:
        ld      a, 92
        call    TXT_OUTPUT
        inc     d
        inc     e
        inc     e
        ld      a, e
        cp      18
        jr      c, dp_row
        ret

draw_tower:
        ld      h, 28
        ld      l, 8
        ld      b, 10
dt_lp:  push    bc
        push    hl
        call    TXT_SET_CURSOR
        ld      a, 1
        call    TXT_SET_PEN
        ld      a, '|'
        call    TXT_OUTPUT
        ld      a, ' '
        call    TXT_OUTPUT
        ld      a, '|'
        call    TXT_OUTPUT
        pop     hl
        inc     l
        pop     bc
        djnz    dt_lp
        ld      h, 27
        ld      l, 7
        call    TXT_SET_CURSOR
        ld      hl, txt_tour
        jp      print_str

; HL = nom, Z si se termine par .vgm
name_has_ext:
        push    hl
nh_lp:  ld      a, (hl)
        or      a
        jr      z, nh_end
        inc     hl
        jr      nh_lp
nh_end: pop     de
        or      a
        sbc     hl, de
        ld      a, l
        cp      5
        jr      c, nh_no
        add     hl, de
        dec     hl
        ld      a, (hl)
        call    upcase
        cp      'M'
        jr      nz, nh_no
        dec     hl
        ld      a, (hl)
        call    upcase
        cp      'G'
        jr      nz, nh_no
        dec     hl
        ld      a, (hl)
        call    upcase
        cp      'V'
        jr      nz, nh_no
        dec     hl
        ld      a, (hl)
        cp      '.'
        jr      nz, nh_no
        xor     a
        ret
nh_no:  or      1
        ret

; ------------------------------------------------------------------------
param_blk:      dw str_desc
str_desc:
str_len:        db 0
                dw str_buf

str_dotdot:     db "..", 0

txt_title:      db "PicoCPC VGM Explorer v5.36", 0
txt_root:       db "HDD", 0
txt_empty:      db "Aucun fichier .vgm", 0
txt_par:        db " <..>", 0
txt_dir:        db " <DIR>", 0
b_su_fr:        db "[SUIV]", 0
b_su_en:        db "[NEXT]", 0
b_su_es:        db "[SIG.]", 0
b_ha_fr:        db "[ALEA]", 0
b_ha_en:        db "[RAND]", 0
b_ha_es:        db "[AZAR]", 0
b_bo_fr:        db "[INFI]", 0
b_bo_en:        db "[LOOP]", 0
b_bo_es:        db "[INFI]", 0
b_1x_fr:        db "[1x]  ", 0
b_1x_en:        db "[1x]  ", 0
b_1x_es:        db "[1x]  ", 0
tab_suite:      dw b_su_fr, b_su_en, b_su_es
tab_hasard:     dw b_ha_fr, b_ha_en, b_ha_es
tab_boucle:     dw b_bo_fr, b_bo_en, b_bo_es
tab_1x:         dw b_1x_fr, b_1x_en, b_1x_es
l1_fr:          db "C: Suivant/Aleatoire     T:FR/EN/ES", 0
l1_en:          db "C: NEXT/RAND             T:FR/EN/ES", 0
l1_es:          db "C: Siguiente/Azar        T:FR/EN/ES", 0
l2_fr:          db "B: Infini/uneFois", 0
l2_en:          db "B: Infinite/oneTime", 0
l2_es:          db "B: Infinito/unaVez", 0
tab_l1:         dw l1_fr, l1_en, l1_es
tab_l2:         dw l2_fr, l2_en, l2_es
txt_demo:       db "Demo pixels", 0
txt_demofoot:   db "Une touche pour revenir", 0
txt_tour:       db "/I", 92, 0
ab_t1_fr:       db "VGM Explorer  v5.36", 0
ab_t1_en:       db "VGM Explorer  v5.36", 0
ab_t1_es:       db "VGM Explorer  v5.36", 0
ab_url:         db "github.com/bakatek/vgmxp", 0
ab_t3_fr:       db "CPC 6128 + PicoCPC ROM5", 0
ab_t3_en:       db "CPC 6128 + PicoCPC ROM5", 0
ab_t3_es:       db "CPC 6128 + PicoCPC ROM5", 0
ab_t4_fr:       db "Teste avec PicoCPC :", 0
ab_t4_en:       db "Tested with PicoCPC:", 0
ab_t4_es:       db "Probado con PicoCPC:", 0
ab_fw:          db "FW rev. 0.9", 0
ab_date:        db "Sep 27 2026  #7d7cbb7c", 0
ab_t7_fr:       db "Une touche pour revenir", 0
ab_t7_en:       db "Press any key to return", 0
ab_t7_es:       db "Una tecla para volver", 0
tab_ab1:        dw ab_t1_fr, ab_t1_en, ab_t1_es
tab_ab3:        dw ab_t3_fr, ab_t3_en, ab_t3_es
tab_ab4:        dw ab_t4_fr, ab_t4_en, ab_t4_es
tab_ab7:        dw ab_t7_fr, ab_t7_en, ab_t7_es
txt_dotvgm:     db ".vgm", 0
txt_playing:    db "Lecture...", 0
txt_esc:        db "ESC = Stop", 0
txt_modeinfo:   db 13, "Info ROM:", 0

depth:          db 0
cursor:         db 0
scroll:         db 0
old_cursor:     db 0
total:          db 0
path_len:       db 0
page_cnt:       db 0
play_mode:      db 0
fold_mode:      db 0
lang:           db 0
cell_col:       db 0
old_scroll:     db 0
gfx_on:         db 0
gfx_deb:        db 0
gfx_x:          db 1
rnd_s:          db 17
stars:          ds 32
loop_one:       db 0
ignore_ok:      db 0
halt_cnt:       db 0
saw_vgm:        db 0
copy_len:       db 0
pend_len:       db 0
tok_len:        db 0
cap_ptr:        dw 0
tok_ptr:        dw 0
sav_out:        ds 3
sav_wait:       ds 3
did_stop:       db 0
sav_key:        ds 3
fly_block:      ds 9

        SAVE 'VGMxp.BIN',#4000,$-#4000,DSK,'build/vgmxp.dsk'