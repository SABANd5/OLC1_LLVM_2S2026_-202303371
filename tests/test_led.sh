#!/bin/sh
set -u
LLVM_BIN=${LLVM_BIN:-/clang64/bin}
PATH="$LLVM_BIN:$PATH"
export PATH
dir=$(mktemp -d build/test-led.XXXXXX) || exit 1
passed=0
failed=0
pass() { echo "OK LED: $1"; passed=$((passed + 1)); }
fail() { echo "FALLO LED: $1"; [ ! -s "$dir/error" ] || cat "$dir/error"; failed=$((failed + 1)); }
reject() {
    name=$1 input=$2 pattern=$3
    printf '%s\n' "$input" > "$dir/input.olc"
    rm -f "$dir/rejected.ll"
    if ! ./bin/compilador.exe --emit-llvm "$dir/input.olc" -o "$dir/rejected.ll" > "$dir/out" 2> "$dir/error" &&
       [ ! -e "$dir/rejected.ll" ] && grep -F "$pattern" "$dir/error" >/dev/null; then pass "$name"
    else fail "$name"; fi
}

if ./bin/compilador.exe --parse-only examples/hardware/led_mega.olc > "$dir/ast" 2> "$dir/error" &&
   tr -d '\r' < "$dir/ast" > "$dir/ast-lf" &&
   printf 'Programa\n  Led 13 on\n' > "$dir/expected" && cmp "$dir/expected" "$dir/ast-lf"; then
    pass 'tokens led y on, sintaxis y AST'
else fail 'tokens led y on, sintaxis y AST'; fi
if ./bin/compilador.exe examples/hardware/led_mega.olc > "$dir/out" 2> "$dir/error" &&
   grep -F 'Led 13 on' "$dir/out" >/dev/null; then pass 'semantica acepta pin 13 y estado on'
else fail 'semantica acepta pin 13 y estado on'; fi
reject 'pin 12 rechazado' 'led 12 on;' 'solo se admite led 13 on'
reject 'pin 14 rechazado' 'led 14 on;' 'solo se admite led 13 on'
reject 'pin con ceros adicionales rechazado' 'led 013 on;' 'solo se admite led 13 on'
reject 'pin enorme rechazado sin overflow' 'led 9999999999999999999999999999999 on;' 'solo se admite led 13 on'
reject 'estado off no admitido' 'led 13 off;' 'error sintactico'
reject 'falta on' 'led 13;' 'error sintactico'
reject 'falta punto y coma' 'led 13 on' 'error sintactico'
reject 'pin decimal' 'led 13.0 on;' 'error sintactico'
reject 'pin como identificador' 'led pin on;' 'error sintactico'
printf 'let ledx = 1; let only = 2; print ledx + only;\n' > "$dir/identifiers.olc"
if ./bin/compilador.exe "$dir/identifiers.olc" > "$dir/out" 2> "$dir/error"; then
    pass 'identificadores con prefijos led y on'
else fail 'identificadores con prefijos led y on'; fi
if ./bin/compilador.exe --emit-llvm examples/hardware/led_mega.olc -o "$dir/led.ll" 2> "$dir/error" &&
   grep -Fx 'declare void @olc_led13_on()' "$dir/led.ll" >/dev/null &&
   grep -Fx '  call void @olc_led13_on()' "$dir/led.ll" >/dev/null &&
   llvm-as "$dir/led.ll" -o "$dir/led.bc" 2>> "$dir/error" &&
   opt -passes=verify -disable-output "$dir/led.bc" 2>> "$dir/error"; then
    pass 'llamada LLVM y verificacion llvm-as y opt'
else fail 'llamada LLVM y verificacion llvm-as y opt'; fi
printf 'let a = 3; print a + 2; led 13 on; print 1.5;\n' > "$dir/mixed.olc"
if ./bin/compilador.exe --emit-llvm "$dir/mixed.olc" -o "$dir/mixed.ll" 2> "$dir/error" &&
   grep -F 'call void @print_i32' "$dir/mixed.ll" >/dev/null &&
   grep -F 'call void @olc_led13_on()' "$dir/mixed.ll" >/dev/null &&
   grep -F 'call void @print_f64' "$dir/mixed.ll" >/dev/null &&
   llvm-as "$dir/mixed.ll" -o "$dir/mixed.bc" 2>> "$dir/error" &&
   opt -passes=verify -disable-output "$dir/mixed.bc" 2>> "$dir/error"; then
    pass 'let y print coexisten con LED'
else fail 'let y print coexisten con LED'; fi
if sh scripts/build_avr.sh examples/hardware/led_mega.olc "$dir/firmware" > "$dir/out" 2> "$dir/error" &&
   [ -s "$dir/firmware/firmware.elf" ] && [ -s "$dir/firmware/firmware.hex" ] &&
   [ -s "$dir/firmware/program.ll" ] && [ -s "$dir/firmware/program.bc" ] &&
   [ -s "$dir/firmware/program.S" ] && [ -s "$dir/firmware/program.o" ] &&
   grep -F 'avr:6' "$dir/firmware/architecture.txt" >/dev/null &&
   [ ! -s "$dir/firmware/undefined.txt" ]; then
    pass 'flujo completo AVR y simbolos resueltos'
else fail 'flujo completo AVR y simbolos resueltos'; fi
if avr-nm "$dir/firmware/firmware.elf" | tr -d '\r' | grep -Eq '[[:space:]]T[[:space:]]olc_led13_on$' &&
   avr-objdump -d "$dir/firmware/firmware.elf" | tr -d '\r' > "$dir/disassembly" &&
   sed -n '/<olc_program>:/,/^$/p' "$dir/disassembly" | grep -F '<olc_led13_on>' >/dev/null &&
   sed -n '/<olc_led13_on>:/,/^$/p' "$dir/disassembly" | grep -Eq 'sbi[[:space:]]+0x04,[[:space:]]*7' &&
   sed -n '/<olc_led13_on>:/,/^$/p' "$dir/disassembly" | grep -Eq 'sbi[[:space:]]+0x05,[[:space:]]*7'; then
    pass 'llamada enlazada y DDRB7/PORTB7 en objeto'
else fail 'llamada enlazada y DDRB7/PORTB7 en objeto'; fi
if sh scripts/build_avr.sh "$dir/mixed.olc" "$dir/mixed-firmware" > "$dir/out" 2> "$dir/error" &&
   [ -s "$dir/mixed-firmware/firmware.hex" ] && [ ! -s "$dir/mixed-firmware/undefined.txt" ]; then
    pass 'firmware mixto LED y print'
else fail 'firmware mixto LED y print'; fi
echo "LED: $passed aprobadas, $failed fallidas; ejecucion fisica no verificada"
[ "$failed" -eq 0 ]
