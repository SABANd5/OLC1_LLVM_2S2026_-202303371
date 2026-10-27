#!/bin/sh
set -u
LLVM_BIN=${LLVM_BIN:-/clang64/bin}
PATH="$LLVM_BIN:$PATH"
export PATH
dir=$(mktemp -d build/test-fase5.XXXXXX) || exit 1
passed=0
failed=0
pass() { echo "OK AVR: $1"; passed=$((passed + 1)); }
fail() { echo "FALLO AVR: $1"; [ ! -s "$dir/error" ] || cat "$dir/error"; failed=$((failed + 1)); }

if ./build/runtime_host.exe > "$dir/out" 2> "$dir/error"; then pass 'formato host i32, INT32_MIN y decimales'
else fail 'formato host i32, INT32_MIN y decimales'; fi
if printf '' | avr-gcc -mmcu=atmega2560 -mdouble=64 -dM -E - > "$dir/macros" 2> "$dir/error" &&
   grep -q '#define __SIZEOF_DOUBLE__ 8' "$dir/macros" &&
   grep -q '#define __DBL_MANT_DIG__ 53' "$dir/macros"; then pass 'double de 64 bits'
else fail 'double de 64 bits'; fi
if avr-gcc -mmcu=atmega2560 -mdouble=64 -print-multi-directory | tr -d '\r' | grep -qx 'avr6/double64'; then pass 'multilib avr6/double64'
else fail 'multilib avr6/double64'; fi
libc=$(avr-gcc -mmcu=atmega2560 -mdouble=64 -print-file-name=libc.a | tr -d '\r')
libgcc=$(avr-gcc -mmcu=atmega2560 -mdouble=64 -print-libgcc-file-name | tr -d '\r')
if [ -f "$libc" ] && [ -f "$libgcc" ]; then pass 'bibliotecas libc y libgcc disponibles'
else fail 'bibliotecas libc y libgcc disponibles'; fi
if avr-nm "$libgcc" 2>/dev/null | tr -d '\r' > "$dir/libgcc-symbols" &&
   grep -Eq '[[:space:]][TW][[:space:]]__adddf3$' "$dir/libgcc-symbols" &&
   grep -Eq '[[:space:]][TW][[:space:]]__muldf3$' "$dir/libgcc-symbols" &&
   grep -Eq '[[:space:]][TW][[:space:]]__fixunsdfsi$' "$dir/libgcc-symbols"; then
    pass 'rutinas double y conversion en libgcc'
else fail 'rutinas double y conversion en libgcc'; fi
if avr-gcc -mmcu=atmega2560 -mdouble=64 -std=c11 -Wall -Wextra -Wpedantic -Os -Iruntime/avr -c runtime/avr/format.c -o "$dir/format.o" 2> "$dir/error"; then
    pass 'compilacion de print_i32 y print_f64'
else fail 'compilacion de print_i32 y print_f64'; fi
if avr-gcc -mmcu=atmega2560 -mdouble=64 -DF_CPU=16000000UL -std=c11 -Wall -Wextra -Wpedantic -Os -Iruntime/avr -c runtime/avr/uart.c -o "$dir/uart.o" 2> "$dir/error"; then pass 'compilacion UART'
else fail 'compilacion UART'; fi
if avr-gcc -mmcu=atmega2560 -mdouble=64 -std=c11 -Wall -Wextra -Wpedantic -Os -Iruntime/avr -c runtime/avr/main.c -o "$dir/main.o" 2> "$dir/error"; then pass 'compilacion de main AVR'
else fail 'compilacion de main AVR'; fi
if avr-gcc -mmcu=atmega2560 -mdouble=64 -O1 -S tests/abi_probe.c -o "$dir/abi-gcc.S" 2> "$dir/error" &&
   ./bin/compilador.exe --emit-llvm tests/abi_probe.olc -o "$dir/abi.ll" 2>> "$dir/error" &&
   llvm-as "$dir/abi.ll" -o "$dir/abi.bc" 2>> "$dir/error" &&
   llc -mtriple=avr -mcpu=atmega2560 "$dir/abi.bc" -o "$dir/abi-llvm.S" 2>> "$dir/error" &&
   avr-gcc -mmcu=atmega2560 -mdouble=64 -c tests/abi_probe.c -o "$dir/abi-gcc.o" 2>> "$dir/error" &&
   avr-gcc -mmcu=atmega2560 -mdouble=64 -c "$dir/abi-llvm.S" -o "$dir/abi-llvm.o" 2>> "$dir/error"; then pass 'generacion de sondas ABI'
else fail 'generacion de sondas ABI'; fi
if grep -Eq 'sts[[:space:]]+captured_f64,r18' "$dir/abi-gcc.S" &&
   grep -Eq 'sts[[:space:]]+captured_f64\+7,r25' "$dir/abi-gcc.S" &&
   grep -Eq 'ldi[[:space:]]+r18,[[:space:]]*0' "$dir/abi-llvm.S" &&
   grep -Eq 'ldi[[:space:]]+r19,[[:space:]]*0' "$dir/abi-llvm.S" &&
   grep -Eq 'movw[[:space:]]+r20,[[:space:]]*r18' "$dir/abi-llvm.S" &&
   grep -Eq 'movw[[:space:]]+r22,[[:space:]]*r18' "$dir/abi-llvm.S" &&
   grep -Eq 'ldi[[:space:]]+r24,[[:space:]]*4' "$dir/abi-llvm.S" &&
   grep -Eq 'ldi[[:space:]]+r25,[[:space:]]*64' "$dir/abi-llvm.S" &&
   grep -Eq 'call[[:space:]]+print_f64' "$dir/abi-llvm.S"; then pass 'sonda f64: registros de llamada y receptor'
else fail 'sonda f64: registros de llamada y receptor'; fi
if grep -Eq 'sts[[:space:]]+captured_i32,r22' "$dir/abi-gcc.S" &&
   grep -Eq 'sts[[:space:]]+captured_i32\+3,r25' "$dir/abi-gcc.S" &&
   grep -Eq 'ldi[[:space:]]+r22,[[:space:]]*103' "$dir/abi-llvm.S" &&
   grep -Eq 'ldi[[:space:]]+r23,[[:space:]]*69' "$dir/abi-llvm.S" &&
   grep -Eq 'ldi[[:space:]]+r24,[[:space:]]*35' "$dir/abi-llvm.S" &&
   grep -Eq 'ldi[[:space:]]+r25,[[:space:]]*1' "$dir/abi-llvm.S"; then pass 'sonda i32: registros de llamada y receptor'
else fail 'sonda i32: registros de llamada y receptor'; fi
printf 'extern void olc_program(void); int main(void) { olc_program(); for (;;) {} }\n' > "$dir/probe-main.c"
if avr-gcc -mmcu=atmega2560 -mdouble=64 "$dir/probe-main.c" "$dir/abi-gcc.o" "$dir/abi-llvm.o" -o "$dir/probe.elf" 2> "$dir/error" &&
   [ -s "$dir/probe.elf" ] && [ -z "$(avr-nm --undefined-only "$dir/probe.elf")" ]; then pass 'sonda LLVM a receptor C enlazada'
else fail 'sonda LLVM a receptor C enlazada'; fi
if sh scripts/build_avr.sh examples/enteros.olc "$dir/entero" > "$dir/out" 2> "$dir/error"; then pass 'enlace de programa entero'
else fail 'enlace de programa entero'; fi
if [ -s "$dir/entero/firmware.elf" ] && [ -s "$dir/entero/firmware.hex" ]; then pass 'ELF y HEX no vacios'
else fail 'ELF y HEX no vacios'; fi
if [ -f "$dir/entero/undefined.txt" ] && [ ! -s "$dir/entero/undefined.txt" ]; then pass 'sin simbolos sin resolver'
else fail 'sin simbolos sin resolver'; fi
if avr-nm "$dir/entero/firmware.elf" | grep -Eq '[[:space:]]T[[:space:]]olc_program$' &&
   avr-nm "$dir/entero/firmware.elf" | grep -Eq '[[:space:]]T[[:space:]]print_i32$' &&
   avr-nm "$dir/entero/firmware.elf" | grep -Eq '[[:space:]]T[[:space:]]print_f64$'; then pass 'simbolos de entrada e impresion resueltos'
else fail 'simbolos de entrada e impresion resueltos'; fi
if grep -q 'elf32-avr' "$dir/entero/architecture.txt" && grep -q 'avr:6' "$dir/entero/architecture.txt"; then pass 'arquitectura AVR6'
else fail 'arquitectura AVR6'; fi
if grep -q 'Program:' "$dir/entero/size.txt" && grep -q 'Data:' "$dir/entero/size.txt"; then pass 'tamano de memoria inspeccionado'
else fail 'tamano de memoria inspeccionado'; fi
if sh scripts/build_avr.sh examples/decimales.olc "$dir/decimal" > "$dir/out" 2> "$dir/error" &&
   [ -s "$dir/decimal/firmware.hex" ]; then pass 'enlace decimal provisional'
else fail 'enlace decimal provisional'; fi
if sh scripts/build_avr.sh examples/mixto.olc "$dir/mixto" > "$dir/out" 2> "$dir/error" &&
   [ -s "$dir/mixto/firmware.hex" ] &&
   [ "$(grep -c 'call void @print_' "$dir/mixto/program.ll")" -eq 2 ]; then pass 'enlace mixto y multiples print'
else fail 'enlace mixto y multiples print'; fi
if sh scripts/build_avr.sh examples/mixto.olc "$dir/mixto-2" > "$dir/out" 2> "$dir/error" &&
   cmp "$dir/mixto/firmware.hex" "$dir/mixto-2/firmware.hex"; then pass 'construccion reproducible HEX'
else fail 'construccion reproducible HEX'; fi
printf 'print no_declarada;\n' > "$dir/invalid.olc"
if ! sh scripts/build_avr.sh "$dir/invalid.olc" "$dir/invalido" > "$dir/out" 2> "$dir/error" &&
   [ ! -e "$dir/invalido" ] && ! ls "$dir"/invalido.tmp.* >/dev/null 2>&1; then pass 'error semantico sin firmware parcial'
else fail 'error semantico sin firmware parcial'; fi
if ! sh scripts/build_avr.sh examples/mixto.olc "$dir/mixto" > "$dir/out" 2> "$dir/error" &&
   [ -s "$dir/mixto/firmware.hex" ]; then pass 'no reemplaza firmware existente'
else fail 'no reemplaza firmware existente'; fi
mkdir -p "$dir/fake"
FASE5_REAL_AVR_GCC=$(command -v avr-gcc)
export FASE5_REAL_AVR_GCC
cat > "$dir/fake/avr-gcc" <<'EOF'
#!/bin/sh
for arg do case "$arg" in */firmware.elf) echo 'fallo de enlace simulado' >&2; exit 1;; esac; done
exec "$FASE5_REAL_AVR_GCC" "$@"
EOF
chmod +x "$dir/fake/avr-gcc"
if ! LLVM_BIN="$dir/fake" sh scripts/build_avr.sh examples/enteros.olc "$dir/fallo" > "$dir/out" 2> "$dir/error" &&
   grep -q 'fallo de enlace simulado' "$dir/error" && [ ! -e "$dir/fallo" ] &&
   ! ls "$dir"/fallo.tmp.* >/dev/null 2>&1; then pass 'fallo de enlace no publica firmware'
else fail 'fallo de enlace no publica firmware'; fi
echo "Integracion AVR: $passed aprobadas, $failed fallidas; placa y runtime docente: no verificados"
[ "$failed" -eq 0 ]
