logo.prg: logo.asm
	64tass --cbm-prg -o logo.prg logo.asm

.PHONY: clean
clean:
	rm -f logo.prg
