;-------------------------------------------------------------------------------
; Logo LILIS su C64
;
; Pasquale 'sid' Fiorillo
; MIT License
; 
; Legge i pixel da una matrice 'bitmap' ed effettua un up-scale da 1x1 pixel a NxN pixel.
; Per ogni '1' nei dati, disegna un blocco NxN caratteri PETSCII $A0 (cursore pieno)
; Per ogni '0' nei dati, lascia l'area NxN vuota (colore di sfondo)
;-------------------------------------------------------------------------------

; La ROM del Commodore 64 (C64) è divisa in due parti:
; - KERNAL: contiene le routine di sistema per gestire I/O, schermo, tastiera, ecc.
; - BASIC: il linguaggio di programmazione di base del C64, che permette di scrivere programmi in modo semplice.
; Questo programma è scritto in assembly e può essere caricato ed eseguito tramite il comando SYS in BASIC.
; Per evitare di scrivere a mano il comando SYS, il programma inizia con una riga BASIC che lo carica automaticamente.

* = $0801  ; Indirizzo di inizio standard per programmi caricati da BASIC
; Il program counter del C64 parte proprio da $0801.

    .word $080C     ; Puntatore alla prossima riga (indirizzo fine riga)
    .word 10        ; Numero di riga BASIC
    .byte $9E       ; Token SYS
    .byte $20       ; Spazio
    .text "4096"    ; L'istruzione SYS 4096 ($1000 in esadecimale)
    .byte 0         ; Fine riga
    .word 0         ; Fine programma BASIC

* = $1000  ; Indirizzo di inizio effettivo del codice assembly

;-------------------------------------------------------------------------------
; Costanti
;-------------------------------------------------------------------------------
; La memoria del C64 è divisa in aree specifiche per schermo, colori, RAM, ecc.
; Anche se i chip video sono separati dalla CPU, il C64 li mappa in memoria, e 
; la CPU può accedere direttamente a queste aree come se fossero RAM.
; Sarà poi la circuiteria del C64 a gestire le operazioni di I/O con i chip video.
BORDER_COLOR_ADDR     = $D020  ; Indirizzo del colore del bordo
BACKGROUND_COLOR_ADDR = $D021  ; Indirizzo del colore di sfondo
SCREEN_RAM_ADDR       = $0400  ; Indirizzo base della RAM dello schermo (40x25 caratteri)
COLOR_RAM_ADDR        = $D800  ; Indirizzo base della RAM dei colori
CLEAR_SCREEN_KERNAL_ADDR = $E544 ; Indirizzo della routine KERNAL per pulire lo schermo
SCREEN_WIDTH_CHARS    = 40     ; Larghezza dello schermo in caratteri

C64_COLOR_BLACK       = $00    ; Codice colore Nero
C64_COLOR_WHITE       = $01    ; Codice colore Bianco

PETSCII_BLOCK         = $A0    ; Carattere "cursore" pieno (SHIFT+Spazio)
BLOCK_WIDTH = 2                ; 2x2 blocchi di caratteri

NUMBER_OF_BITMAP_ROWS  = 9     ; Numero di righe nella definizione 'bitmap'
NUMBER_OF_BITMAP_COLS  = 10    ; Numero di colonne nella definizione 'bitmap'

LOGO_OFFSET_X_CHARS   = 10     ; Offset orizzontale dall'angolo in alto a sx
LOGO_OFFSET_Y_CHARS   = 4      ; Offset verticale dall'angolo in alto a sx

;-------------------------------------------------------------------------------
; Variabili in Zero Page
;-------------------------------------------------------------------------------
; La Zero Page è la parte di memoria RAM compresa tra gli indirizzi $0000 - $00FF
;
; Questa parte di memoria è molto veloce da accedere (meno cicli cpu) e viene
; utilizzata, come convenzione, per variabili temporanee e puntatori accedute
; frequentemente.
;
; È chiamata "Zero Page" perché il byte "alto" dell'indirizzo (16 bit) è 0.
; Ad esempio, $00A3 è in Zero Page, mentre $02A3 non lo è.
; La Zero Page è accessibile con istruzioni a 1 byte, rendendo le operazioni più
; veloci.
;-------------------------------------------------------------------------------
; Sono divisi in byte bassi e alti per poter gestire indirizzi a 16 bit.

ZP_BITMAP_DATA_PTR_L     = $F0  ; Byte basso del puntatore ai dati 'bitmap'
ZP_BITMAP_DATA_PTR_H     = $F1  ; Byte alto del puntatore ai dati 'bitmap'

ZP_SCREEN_ROW_START_L   = $F2  ; Byte basso del puntatore all'inizio della riga corrente del logo (sullo schermo)
ZP_SCREEN_ROW_START_H   = $F3  ; Byte alto del puntatore all'inizio della riga corrente del logo (sullo schermo)
ZP_COLOR_ROW_START_L    = $F4  ; Byte basso del puntatore all'inizio della riga corrente del logo (nella RAM colori)
ZP_COLOR_ROW_START_H    = $F5  ; Byte alto del puntatore all'inizio della riga corrente del logo (nella RAM colori)

ZP_CURR_SCR_CHAR_L      = $F6  ; Byte basso del puntatore al carattere corrente del blocco (sullo schermo)
ZP_CURR_SCR_CHAR_H      = $F7  ; Byte alto del puntatore al carattere corrente del blocco (sullo schermo)
ZP_CURR_CLR_CHAR_L      = $F8  ; Byte basso del puntatore al colore corrente del blocco (nella RAM colori)
ZP_CURR_CLR_CHAR_H      = $F9  ; Byte alto del puntatore al colore corrente del blocco (nella RAM colori)

; Puntatori temporanei usati dalla subroutine draw_block_sub
ZP_BLOCK_DRAW_SCR_L     = $FA  ; Byte basso del puntatore schermo per disegnare il blocco
ZP_BLOCK_DRAW_SCR_H     = $FB  ; Byte alto del puntatore schermo per disegnare il blocco
ZP_BLOCK_DRAW_CLR_L     = $FC  ; Byte basso del puntatore colore per disegnare il blocco
ZP_BLOCK_DRAW_CLR_H     = $FD  ; Byte alto del puntatore colore per disegnare il blocco


;===============================================================================
; Main
;===============================================================================
start_program:
    ; --- Impostazione Colori Iniziali ---
    jsr CLEAR_SCREEN_KERNAL_ADDR ; Chiama la routine KERNAL per pulire lo schermo
    lda #C64_COLOR_WHITE         ; Carica il colore bianco nel registro A (chiamato "accumulatore")
    sta BORDER_COLOR_ADDR        ; Scrive il valore del registro A nella locazione di memoria
                                 ; $BORDER_COLOR_ADDR ($D020), che imposta il colore del bordo
    sta BACKGROUND_COLOR_ADDR    ; Stessa cosa nella locazione di memoria per il colore di sfondo

    ; --- Inizializzazione Puntatori Dati 'bitmap' ---
    lda #<bitmap                 ; Carica il byte basso dell'indirizzo dell'etichetta 'bitmap'
    sta ZP_BITMAP_DATA_PTR_L     ; Salva nella locazione zero page
    lda #>bitmap                 ; Carica il byte alto dell'indirizzo dell'etichetta 'bitmap'
    sta ZP_BITMAP_DATA_PTR_H     ; Salva nella locazione zero page

    ; --- Inizializzazione Puntatori Schermo e Colore per il Logo ---
    ; Il logo inizia a (LOGO_OFFSET_Y_CHARS * SCREEN_WIDTH_CHARS) + LOGO_OFFSET_X_CHARS
    ; Esempio: (5 * 40) + 5 = 200 + 5 = 205 bytes dall'inizio della RAM schermo/colori.
    ; SCREEN_RAM_ADDR + 205 = $0400 + $CD = $04CD
    ; COLOR_RAM_ADDR + 205  = $D800 + $CD = $D8CD

    ; Calcoliamo l'offset iniziale (valore a 16 bit)
    ; Usiamo i registri temporaneamente per il calcolo.
    ; Offset = (LOGO_OFFSET_Y_CHARS * SCREEN_WIDTH_CHARS) + LOGO_OFFSET_X_CHARS
    ; Siccome LOGO_OFFSET_Y_CHARS e SCREEN_WIDTH_CHARS sono piccoli, la moltiplicazione
    ; (5*40 = 200) non andrà in overflow su 8 bit.

    ; Imposta screen_row_start_ptr = SCREEN_RAM_ADDR + offset
    lda #< (SCREEN_RAM_ADDR + (LOGO_OFFSET_Y_CHARS * SCREEN_WIDTH_CHARS) + LOGO_OFFSET_X_CHARS)
    sta ZP_SCREEN_ROW_START_L
    lda #> (SCREEN_RAM_ADDR + (LOGO_OFFSET_Y_CHARS * SCREEN_WIDTH_CHARS) + LOGO_OFFSET_X_CHARS)
    sta ZP_SCREEN_ROW_START_H

    ; Imposta color_row_start_ptr = COLOR_RAM_ADDR + offset
    lda #< (COLOR_RAM_ADDR + (LOGO_OFFSET_Y_CHARS * SCREEN_WIDTH_CHARS) + LOGO_OFFSET_X_CHARS)
    sta ZP_COLOR_ROW_START_L
    lda #> (COLOR_RAM_ADDR + (LOGO_OFFSET_Y_CHARS * SCREEN_WIDTH_CHARS) + LOGO_OFFSET_X_CHARS)
    sta ZP_COLOR_ROW_START_H

    ; --- Loop Principale Esterno (per ogni riga di dati 'bitmap') ---
    ldx #NUMBER_OF_BITMAP_ROWS   ; Inizializza il contatore X per le righe di 'bitmap'

outer_bitmap_row_loop:
    ; All'inizio di ogni riga di 'bitmap', copia i puntatori base di riga
    ; nei puntatori correnti per il carattere/blocco.
    lda ZP_SCREEN_ROW_START_L
    sta ZP_CURR_SCR_CHAR_L
    lda ZP_SCREEN_ROW_START_H
    sta ZP_CURR_SCR_CHAR_H

    lda ZP_COLOR_ROW_START_L
    sta ZP_CURR_CLR_CHAR_L
    lda ZP_COLOR_ROW_START_H
    sta ZP_CURR_CLR_CHAR_H

    ldy #0                      ; Inizializza il registro Y come indice per le colonne di 'bitmap'

inner_bitmap_col_loop:
    ; Carica un byte di dati da (ZP_BITMAP_DATA_PTR_L),Y
    lda (ZP_BITMAP_DATA_PTR_L),y ; Legge il valore (0 o 1) dalla tabella 'bitmap'
    cmp #1                      ; Confronta con 1
    bne skip_drawing_block      ; Se non è 0, salta il disegno del blocco

    ; Se è 1: disegna il blocco
    jsr draw_block_sub        ; Chiama la subroutine per disegnare il blocco

skip_drawing_block:
    ; Avanza i puntatori correnti di schermo e colore di N posizioni (BLOCK_WIDTH) orizzontalmente
    ; ZP_CURR_SCR_CHAR_L/H += BLOCK_WIDTH
    lda ZP_CURR_SCR_CHAR_L
    clc                         ; Pulisce il flag di carry
    adc #BLOCK_WIDTH            ; Aggiunge BLOCK_WIDTH al byte basso del puntatore corrente
    sta ZP_CURR_SCR_CHAR_L      ; Salva il nuovo valore nel puntatore corrente schermo
    bcc no_carry_scr_horiz      ; Se non c'è carry, continua
    inc ZP_CURR_SCR_CHAR_H      ; Altrimenti incrementa il byte alto del puntatore corrente schermo
no_carry_scr_horiz:

    ; ZP_CURR_CLR_CHAR_L/H += BLOCK_WIDTH
    lda ZP_CURR_CLR_CHAR_L
    clc                         ; Pulisce il flag di carry
    adc #BLOCK_WIDTH            ; Aggiunge BLOCK_WIDTH al byte basso del puntatore corrente colore
    sta ZP_CURR_CLR_CHAR_L      ; Salva il nuovo valore nel puntatore corrente colore
    bcc no_carry_clr_horiz      ; Se non c'è carry, continua
    inc ZP_CURR_CLR_CHAR_H      ; Altrimenti incrementa il byte alto del puntatore corrente colore
no_carry_clr_horiz:

    iny                         ; Passa alla prossima colonna nei dati 'bitmap'
    cpy #NUMBER_OF_BITMAP_COLS  ; Abbiamo processato tutte le colonne?
    bne inner_bitmap_col_loop   ; Se no, continua il loop interno

    ; Fine del loop interno (processata una riga di 'bitmap')
    ; Avanza il puntatore ai dati 'bitmap' alla prossima riga di dati
    ; ZP_BITMAP_DATA_PTR_L/H += NUMBER_OF_BITMAP_COLS (10 bytes)
    lda ZP_BITMAP_DATA_PTR_L    ; Carica il byte basso del puntatore ai dati 'bitmap'
    clc                         ; Pulisce il flag di carry
    adc #NUMBER_OF_BITMAP_COLS  ; Aggiunge il numero di colonne della 'bitmap'
    sta ZP_BITMAP_DATA_PTR_L    ; Salva il nuovo valore nel puntatore ai dati 'bitmap'
    bcc no_carry_bitmap_ptr     ; Se non c'è carry, continua
    inc ZP_BITMAP_DATA_PTR_H    ; Altrimenti incrementa il byte alto del puntatore ai dati 'bitmap'
no_carry_bitmap_ptr:

    ; Avanza i puntatori di inizio riga (schermo e colore) per la prossima "linea" del logo.
    ; Ogni 'line' corrisponde a N (BLOCK_WIDTH) righe di caratteri sullo schermo.
    ; Quindi, avanziamo di (BLOCK_WIDTH * SCREEN_WIDTH_CHARS) bytes.
    ; Lo facciamo aggiungendo SCREEN_WIDTH_CHARS BLOCK_WIDTH volte
    ; (non esiste un'istruzione per moltiplicare direttamente in 6502).
    ldy #BLOCK_WIDTH                    ; Contatore per le BLOCK_WIDTH righe di caratteri da saltare
advance_start_row_pointers_loop:
    ; ZP_SCREEN_ROW_START_L/H += SCREEN_WIDTH_CHARS (40)
    lda ZP_SCREEN_ROW_START_L           ; Carica il byte basso del puntatore alla riga corrente dello schermo
    clc                                 ; Pulisce il flag di carry
    adc #SCREEN_WIDTH_CHARS             ; Aggiunge SCREEN_WIDTH_CHARS al byte basso
    sta ZP_SCREEN_ROW_START_L           ; Salva il nuovo valore nel puntatore alla riga corrente dello schermo
    bcc no_carry_screen_row             ; Se non c'è carry, continua
    inc ZP_SCREEN_ROW_START_H           ; Altrimenti incrementa il byte alto del puntatore alla riga corrente dello schermo
no_carry_screen_row:

    ; ZP_COLOR_ROW_START_L/H += SCREEN_WIDTH_CHARS (40)
    lda ZP_COLOR_ROW_START_L            ; Carica il byte basso del puntatore alla riga corrente dei colori
    clc                                 ; Pulisce il flag di carry
    adc #SCREEN_WIDTH_CHARS             ; Aggiunge SCREEN_WIDTH_CHARS al byte basso
    sta ZP_COLOR_ROW_START_L            ; Salva il nuovo valore nel puntatore alla riga corrente dei colori
    bcc no_carry_color_row              ; Se non c'è carry, continua
    inc ZP_COLOR_ROW_START_H            ; Altrimenti incrementa il byte alto del puntatore alla riga corrente dei colori
no_carry_color_row:
    dey                                 ; Decrementa il contatore delle righe di 'bitmap' (BLOCK_WIDTH) 
    bne advance_start_row_pointers_loop ; Se ci sono altre righe, continua

    dex                                 ; Decrementa il contatore delle righe di 'bitmap' (loop esterno)
    bne outer_bitmap_row_loop           ; Se ci sono altre righe, continua

    ; --- Fine della bitmap ---
    rts                                 ; Ritorna al BASIC (fine del programma SYS)

;===============================================================================
; Subroutine: draw_block_sub
; Disegna un blocco (BLOCK_WIDTH x BLOCK_WIDTH) di PETSCII_BLOCK ($A0) utilizzando
; il colore C64_COLOR_BLACK.
; Input: ZP_CURR_SCR_CHAR_L/H e ZP_CURR_CLR_CHAR_L/H puntano
;        all'angolo in alto a sinistra del blocco da disegnare.
; Utilizza ZP_BLOCK_DRAW_SCR_L/H e ZP_BLOCK_DRAW_CLR_L/H come puntatori interni.
; Registri usati: A, X, Y. Salva e ripristina quelli usati dal chiamante.
;===============================================================================
draw_block_sub:
    ; Salva i registri A, X, Y del chiamante perché li modificheremo
    pha                         ; Salva Accumulatore
    txa                         ; Trasferisci X in A
    pha                         ; Salva X (originale)
    tya                         ; Trasferisci Y in A
    pha                         ; Salva Y (originale)

    ; Copia i puntatori correnti (passati implicitamente tramite ZP)
    ; nei puntatori temporanei per il disegno del blocco.
    lda ZP_CURR_SCR_CHAR_L
    sta ZP_BLOCK_DRAW_SCR_L
    lda ZP_CURR_SCR_CHAR_H
    sta ZP_BLOCK_DRAW_SCR_H

    lda ZP_CURR_CLR_CHAR_L
    sta ZP_BLOCK_DRAW_CLR_L
    lda ZP_CURR_CLR_CHAR_H
    sta ZP_BLOCK_DRAW_CLR_H

    ; Inizializza il contatore X per le N righe del blocco
    ldx #BLOCK_WIDTH            ; N righe da disegnare per il blocco

block_row_loop:                 ; Loop per ogni riga del blocco
    ; Inizializza l'indice Y per le N colonne del blocco
    ldy #0                      ; Indice colonna (0, 1, 2, ...) all'interno della riga del blocco

block_col_loop:                 ; Loop per ogni colonna del blocco
    ; Disegna un carattere del blocco
    lda #PETSCII_BLOCK          ; Carica il carattere $A0 (blocco pieno in PETSCII) nell'accumulatore
    sta (ZP_BLOCK_DRAW_SCR_L),y ; Scrivi il carattere nella RAM schermo
    lda #C64_COLOR_BLACK        ; Carica il colore nero nell'accumulatore
    sta (ZP_BLOCK_DRAW_CLR_L),y ; Scrivi il colore nella RAM colori
    iny                         ; Prossima colonna all'interno del blocco
    cpy #BLOCK_WIDTH            ; Raggiunto il BLOCK_WIDTH per le colonne?
    bne block_col_loop          ; No, continua

    ; Fine di una riga del blocco.
    ; Avanza i puntatori di disegno (ZP_BLOCK_DRAW_SCR_L/H e ZP_BLOCK_DRAW_CLR_L/H)
    ; alla riga successiva sullo schermo (cioè + SCREEN_WIDTH_CHARS).
    ; ZP_BLOCK_DRAW_SCR_L/H += SCREEN_WIDTH_CHARS (40)
    lda ZP_BLOCK_DRAW_SCR_L     ; Carica il byte basso del puntatore schermo per disegnare il blocco
    clc                         ; Pulisce il flag di carry
    adc #SCREEN_WIDTH_CHARS     ; Aggiunge SCREEN_WIDTH_CHARS al byte basso
    sta ZP_BLOCK_DRAW_SCR_L     ; Salva il nuovo valore nel puntatore schermo per disegnare il blocco
    bcc no_carry_block_scr      ; Se non c'è carry, continua
    inc ZP_BLOCK_DRAW_SCR_H     ; Altrimenti incrementa il byte alto del puntatore schermo per disegnare il blocco
no_carry_block_scr:

    ; ZP_BLOCK_DRAW_CLR_L/H += SCREEN_WIDTH_CHARS (40)
    lda ZP_BLOCK_DRAW_CLR_L     ; Carica il byte basso del puntatore colore per disegnare il blocco
    clc                         ; Pulisce il flag di carry
    adc #SCREEN_WIDTH_CHARS     ; Aggiunge SCREEN_WIDTH_CHARS al byte basso
    sta ZP_BLOCK_DRAW_CLR_L     ; Salva il nuovo valore nel puntatore colore per disegnare il blocco
    bcc no_carry_block_clr      ; Se non c'è carry, continua
    inc ZP_BLOCK_DRAW_CLR_H     ; Altrimenti incrementa il byte alto del puntatore colore per disegnare il blocco
no_carry_block_clr:

    dex                         ; Decrementa il contatore delle righe del blocco
    bne block_row_loop          ; Se ci sono altre righe del blocco, continua

    ; Fine della subroutine draw_block_sub
    ; Ripristina i registri del chiamante
    pla                         ; Ripristina Y (originale)
    tay                         ; Metti in Y
    pla                         ; Ripristina X (originale)
    tax                         ; Metti in X
    pla                         ; Ripristina Accumulatore
    rts                         ; Ritorna al chiamante

;===============================================================================
; Dati del Logo (bitmap)
; 
; Ogni bit rappresenta un "pixel" del logo che sarà up-scalato a un blocco.
; 1 = disegna blocco, 0 = vuoto.
; Ogni blocco è definito come N x N caratteri (default 2x2)
;
; Il numero di righe e colonne non può essere superiore a 16 poiché vengono utilizzati
; 2 puntatori a 8 bit per rappresentare l'indirizzo dei dati 'bitmap' (totale 16 bit).
; Considerare anche BLOCK_WIDTH per ogni pixel e tenere in mente che il logo in 
; versione up-scalata non può essere più grande di 40x25 caratteri.
;===============================================================================
bitmap:
    .byte 1,0,1,0,1,0,1,0,1,1   ; linea 0
    .byte 1,0,1,0,1,0,1,0,0,1   ; linea 1
    .byte 1,0,1,0,1,0,1,0,0,1   ; linea 2
    .byte 1,0,1,0,1,0,1,0,0,0   ; linea 3
    .byte 1,0,1,0,1,0,1,0,0,0   ; linea 4
    .byte 1,0,1,0,1,0,1,0,1,1   ; linea 5
    .byte 1,0,0,0,1,0,0,0,0,1   ; linea 6
    .byte 1,0,0,0,1,0,0,0,0,1   ; linea 7
    .byte 1,1,1,0,1,1,1,0,1,1   ; linea 8

; End