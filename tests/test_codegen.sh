#!/bin/sh
set -u
# Override when MSYS2 is installed elsewhere. LLVM must have the AVR target.
LLVM_BIN=${LLVM_BIN:-/clang64/bin}
PATH="$LLVM_BIN:$PATH"
export PATH
dir=build/test-fase4
mkdir -p "$dir"
passed=0
failed=0

pass() { echo "OK: $1"; passed=$((passed + 1)); }
fail() { echo "FALLO: $1"; [ ! -f "$dir/error" ] || cat "$dir/error"; failed=$((failed + 1)); }

emit() {
    printf '%s\n' "$1" > "$dir/input.olc"
    ./bin/compilador.exe --emit-llvm "$dir/input.olc" -o "$dir/output.ll" > "$dir/stdout" 2> "$dir/error" &&
        llvm-as "$dir/output.ll" -o "$dir/output.bc" 2>> "$dir/error" &&
        opt -passes=verify -disable-output "$dir/output.bc" 2>> "$dir/error"
}
valid() {
    name=$1 input=$2 pattern=$3
    if emit "$input" && grep -F -- "$pattern" "$dir/output.ll" >/dev/null; then pass "$name"; else fail "$name"; fi
}
invalid() {
    name=$1 input=$2 pattern=$3
    printf '%s\n' "$input" > "$dir/input.olc"
    rm -f "$dir/rejected.ll"
    if ./bin/compilador.exe --emit-llvm "$dir/input.olc" -o "$dir/rejected.ll" > "$dir/stdout" 2> "$dir/error"; then
        fail "$name"
    elif [ ! -e "$dir/rejected.ll" ] && [ ! -s "$dir/stdout" ] && grep -F "$pattern" "$dir/error" >/dev/null; then
        pass "$name"
    else fail "$name"; fi
}

valid 'literal entero' 'print 10;' 'call void @print_i32(i32 10)'
valid 'literal decimal preciso' 'print 0.1;' 'call void @print_f64(double 0x3FB999999999999A)'
valid 'suma entera' 'print 4 + 2;' '%t1 = add i32 4, 2'
valid 'resta entera' 'print 4 - 2;' '%t1 = sub i32 4, 2'
valid 'multiplicacion entera' 'print 4 * 2;' '%t1 = mul i32 4, 2'
valid 'division entera sdiv' 'print 4 / 2;' '%t1 = sdiv i32 4, 2'
valid 'suma decimal' 'print 4.0 + 2.0;' '%t1 = fadd double'
valid 'resta decimal' 'print 4.0 - 2.0;' '%t1 = fsub double'
valid 'multiplicacion decimal' 'print 4.0 * 2.0;' '%t1 = fmul double'
valid 'division decimal' 'print 4.0 / 2.0;' '%t1 = fdiv double'
valid 'precedencia' 'print 1 + 2 * 3;' '%t2 = add i32 1, %t1'
valid 'asociatividad izquierda' 'print 8 - 4 - 2;' '%t2 = sub i32 %t1, 2'
valid 'parentesis' 'print (1 + 2) * 3;' '%t2 = mul i32 %t1, 3'
valid 'variables enteras' 'let a = 10; print a;' 'call void @print_i32(i32 10)'
valid 'variables decimales' 'let a = 2.5; print a;' 'call void @print_f64(double 0x4004000000000000)'
valid 'referencias y temporales' 'let a = 10; let b = a + 5; print b + a;' '%t2 = add i32 %t1, 10'
valid 'print entero' 'print 42;' 'call void @print_i32(i32 42)'
valid 'print decimal' 'print 2.5;' 'call void @print_f64(double 0x4004000000000000)'
if emit 'print (10 + 20) * (30 - 5);' &&
   grep -F '%t1 = add i32 10, 20' "$dir/output.ll" >/dev/null &&
   grep -F '%t2 = sub i32 30, 5' "$dir/output.ll" >/dev/null &&
   grep -F '%t3 = mul i32 %t1, %t2' "$dir/output.ll" >/dev/null &&
   [ "$(grep -cE '^  %t[0-9]+ =' "$dir/output.ll")" -eq 3 ]; then
    pass 'temporales unicos y ordenados'
else fail 'temporales unicos y ordenados'; fi
if emit 'let a = 2; let b = 3.0; print a; print b;' &&
   grep -F 'call void @print_i32(i32 2)' "$dir/output.ll" >/dev/null &&
   grep -F 'call void @print_f64(double 0x4008000000000000)' "$dir/output.ll" >/dev/null; then
    pass 'multiples instrucciones y ambos print'
else fail 'multiples instrucciones y ambos print'; fi
if emit 'let a = 10 + 2; print a * 3;' &&
   cp "$dir/output.ll" "$dir/first.ll" &&
   ./bin/compilador.exe --emit-llvm "$dir/input.olc" -o "$dir/output.ll" 2> "$dir/error" &&
   cmp "$dir/first.ll" "$dir/output.ll"; then pass 'generacion determinista y reemplazo'
else fail 'generacion determinista y reemplazo'; fi
invalid 'rechazo no declarado' 'print x;' 'no declarada'
invalid 'rechazo duplicado' 'let a = 1; let a = 2;' 'duplicada'
invalid 'rechazo mezcla de tipos' 'print 1 + 2.0;' 'tipos incompatibles'
invalid 'rechazo literal fuera de rango' 'print 2147483648;' 'fuera de rango'
printf 'contenido anterior\n' > "$dir/existing.ll"
printf 'print sin_declarar;\n' > "$dir/input.olc"
if ! ./bin/compilador.exe --emit-llvm "$dir/input.olc" -o "$dir/existing.ll" > "$dir/stdout" 2> "$dir/error" &&
   [ "$(cat "$dir/existing.ll")" = 'contenido anterior' ] &&
   ! ls "$dir"/existing.ll.tmp.* >/dev/null 2>&1; then pass 'error preserva salida anterior y no deja temporales'
else fail 'error preserva salida anterior y no deja temporales'; fi
if emit 'print 1;' && llvm-dis "$dir/output.bc" -o "$dir/recovered.ll" 2>> "$dir/error" &&
   llvm-as "$dir/recovered.ll" -o "$dir/recovered.bc" 2>> "$dir/error"; then pass 'llvm-as y llvm-dis'
else fail 'llvm-as y llvm-dis'; fi
if opt -passes=verify -disable-output "$dir/recovered.bc" 2> "$dir/error"; then pass 'verificacion estructural opt'
else fail 'verificacion estructural opt'; fi
if ./bin/compilador.exe --emit-llvm examples/enteros.olc -o "$dir/entero.ll" 2> "$dir/error" &&
   llvm-as "$dir/entero.ll" -o "$dir/entero.bc" 2>> "$dir/error" &&
   llc -mtriple=avr -mcpu=atmega2560 -filetype=asm "$dir/entero.bc" -o "$dir/entero.S" 2>> "$dir/error" &&
   avr-gcc -mmcu=atmega2560 -c "$dir/entero.S" -o "$dir/entero.o" 2>> "$dir/error" &&
   avr-objdump -f "$dir/entero.o" | grep -F 'elf32-avr' >/dev/null; then pass 'AVR entero: ensamblador y objeto'
else fail 'AVR entero: ensamblador y objeto'; fi
if ./bin/compilador.exe --emit-llvm examples/decimales.olc -o "$dir/decimal.ll" 2> "$dir/error" &&
   llvm-as "$dir/decimal.ll" -o "$dir/decimal.bc" 2>> "$dir/error" &&
   llc -mtriple=avr -mcpu=atmega2560 -filetype=asm "$dir/decimal.bc" -o "$dir/decimal.S" 2>> "$dir/error" &&
   avr-gcc -mmcu=atmega2560 -c "$dir/decimal.S" -o "$dir/decimal.o" 2>> "$dir/error" &&
   avr-objdump -f "$dir/decimal.o" | grep -F 'elf32-avr' >/dev/null; then pass 'AVR decimal: ensamblador y objeto'
else fail 'AVR decimal: ensamblador y objeto'; fi
printf 'print 1;\n' > "$dir/input.olc"
cp "$dir/input.olc" "$dir/source-original"
if ! ./bin/compilador.exe --emit-llvm "$dir/input.olc" -o "$dir/input.olc" 2> "$dir/error" &&
   cmp "$dir/input.olc" "$dir/source-original"; then pass 'proteccion de archivo fuente'
else fail 'proteccion de archivo fuente'; fi
if ! ./bin/compilador.exe --emit-llvm "$dir/input.olc" -o "$dir/no-existe/output.ll" 2> "$dir/error" &&
   [ ! -e "$dir/no-existe/output.ll" ]; then pass 'error de ruta de salida'
else fail 'error de ruta de salida'; fi
mkdir -p "$dir/destino-directorio"
if ! ./bin/compilador.exe --emit-llvm "$dir/input.olc" -o "$dir/destino-directorio" 2> "$dir/error" &&
   [ -d "$dir/destino-directorio" ] && ! ls "$dir"/destino-directorio.tmp.* >/dev/null 2>&1; then
    pass 'error de reemplazo limpia temporal'
else fail 'error de reemplazo limpia temporal'; fi
examples_ok=1
for example in enteros decimales mixto; do
    if ! ./bin/compilador.exe --emit-llvm "examples/$example.olc" -o "$dir/$example.ll" 2> "$dir/error" ||
       ! cmp "examples/llvm/$example.ll" "$dir/$example.ll" ||
       ! llvm-as "$dir/$example.ll" -o "$dir/$example.bc" 2>> "$dir/error" ||
       ! opt -passes=verify -disable-output "$dir/$example.bc" 2>> "$dir/error"; then examples_ok=0; fi
done
if [ "$examples_ok" -eq 1 ]; then pass 'ejemplos entregables reproducibles y validos'
else fail 'ejemplos entregables reproducibles y validos'; fi

echo "LLVM IR: $passed aprobadas, $failed fallidas"
[ "$failed" -eq 0 ]
