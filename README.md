# LILiS logo su Commodore 64

Programmino in assembly per MOS6510 (derivato del 6502) per disegnare il logo LILiS sul Commodore 64.

Il programma definisce una matrice "bitmap" 9x10 in cui i pixel sono rappresentati da bit 1 (pixel pieno) e 0 (pixel vuoto).

Ogni pixel viene poi up-scalato in un blocco di NxN pixel in modo programmatico..

Le costanti all'inizio del listato, come offset, dimensione blocco (NxN), dimensione matrice di origine e colori possono essere modificati.

La matrice di origine può essere espansa al massimo a 16x16. I puntatori sono infatti a 16 bit (1 byte alto e uno basso). Ad ogni modo bisogna considerare il valore di BLOCK_WIDTH (NxN) di modo che post-scale il disegno non occupi più di 40x25 (dimensione dello schermo "caratteri" del C64).

Il listato è commentato in maniera verbosa in italiano.

Have fun,
sid

