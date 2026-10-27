#!/bin/sh
set -eu
if [ "$#" -ne 2 ]; then
    echo "Uso: sh scripts/build_avr.sh programa.olc directorio_salida_nuevo" >&2
    exit 2
fi
input=$1
out=$2
LLVM_BIN=${LLVM_BIN:-/clang64/bin}
PATH="$LLVM_BIN:$PATH"
export PATH

# Never replace a previous build; publish a complete directory only on success.
if [ -e "$out" ]; then echo "La salida ya existe: $out" >&2; exit 1; fi
parent=$(dirname "$out")
mkdir -p "$parent"
tmp=$(mktemp -d "$out.tmp.XXXXXX")
cleanup() { if [ -n "$tmp" ]; then rm -rf -- "$tmp"; fi; }
trap cleanup EXIT HUP INT TERM

./bin/compilador.exe --emit-llvm "$input" -o "$tmp/program.ll"
llvm-as "$tmp/program.ll" -o "$tmp/program.bc"
opt -passes=verify -disable-output "$tmp/program.bc"
llc -mtriple=avr -mcpu=atmega2560 -filetype=asm "$tmp/program.bc" -o "$tmp/program.S"
avr-gcc -mmcu=atmega2560 -mdouble=64 -c "$tmp/program.S" -o "$tmp/program.o"
avr-gcc -mmcu=atmega2560 -mdouble=64 -DF_CPU=16000000UL -std=c11 -Wall -Wextra -Wpedantic -Os \
    -Iruntime/avr -c runtime/avr/format.c -o "$tmp/format.o"
avr-gcc -mmcu=atmega2560 -mdouble=64 -DF_CPU=16000000UL -std=c11 -Wall -Wextra -Wpedantic -Os \
    -Iruntime/avr -c runtime/avr/uart.c -o "$tmp/uart.o"
avr-gcc -mmcu=atmega2560 -mdouble=64 -DF_CPU=16000000UL -std=c11 -Wall -Wextra -Wpedantic -Os \
    -Iruntime/avr -c runtime/avr/main.c -o "$tmp/main.o"
avr-gcc -mmcu=atmega2560 -mdouble=64 "$tmp/program.o" "$tmp/format.o" \
    "$tmp/uart.o" "$tmp/main.o" -o "$tmp/firmware.elf"
avr-nm --undefined-only "$tmp/firmware.elf" > "$tmp/undefined.txt"
if [ -s "$tmp/undefined.txt" ]; then cat "$tmp/undefined.txt" >&2; exit 1; fi
avr-objcopy -O ihex -R .eeprom "$tmp/firmware.elf" "$tmp/firmware.hex"
avr-objdump -f "$tmp/firmware.elf" > "$tmp/architecture.txt"
avr-size -C --mcu=atmega2560 "$tmp/firmware.elf" > "$tmp/size.txt"
if [ -e "$out" ]; then echo "La salida apareció durante la compilación: $out" >&2; exit 1; fi
mv "$tmp" "$out"
tmp=
echo "Firmware enlazado: $out/firmware.elf y $out/firmware.hex (sin prueba física)"
