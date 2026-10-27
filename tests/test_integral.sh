#!/bin/sh
set -u
LLVM_BIN=${LLVM_BIN:-/clang64/bin}
PATH="$LLVM_BIN:$PATH"
export PATH
dir=$(mktemp -d build/test-fase6.XXXXXX) || exit 1
passed=0
failed=0
pass() { echo "OK integral: $1"; passed=$((passed + 1)); }
fail() { echo "FALLO integral: $1"; [ ! -s "$dir/error" ] || cat "$dir/error"; failed=$((failed + 1)); }

valid() {
    name=$1 source=$2 pattern=$3
    printf '%s\n' "$source" > "$dir/input.olc"
    if ./bin/compilador.exe --emit-llvm "$dir/input.olc" -o "$dir/output.ll" > "$dir/out" 2> "$dir/error" &&
       grep -F "$pattern" "$dir/output.ll" >/dev/null &&
       grep -F 'declare void @print_i32(i32)' "$dir/output.ll" >/dev/null &&
       grep -F 'declare void @print_f64(double)' "$dir/output.ll" >/dev/null &&
       llvm-as "$dir/output.ll" -o "$dir/output.bc" 2>> "$dir/error" &&
       opt -passes=verify -disable-output "$dir/output.bc" 2>> "$dir/error" &&
       ./bin/compilador.exe --emit-llvm "$dir/input.olc" -o "$dir/repeat.ll" 2>> "$dir/error" &&
       cmp "$dir/output.ll" "$dir/repeat.ll" &&
       ! grep -E '^  %t[0-9]+ =' "$dir/output.ll" | sed -E 's/^ *(%t[0-9]+).*/\1/' | sort | uniq -d | grep . >/dev/null; then
        pass "$name"
    else fail "$name"; fi
}
invalid() {
    name=$1 source=$2 pattern=$3
    printf '%s' "$source" > "$dir/input.olc"
    rm -f "$dir/invalid.ll"
    if ! ./bin/compilador.exe --emit-llvm "$dir/input.olc" -o "$dir/invalid.ll" > "$dir/out" 2> "$dir/error" &&
       [ ! -e "$dir/invalid.ll" ] && grep -F "$pattern" "$dir/error" >/dev/null; then pass "$name"
    else fail "$name"; fi
}

valid 'cero' 'print 0;' 'call void @print_i32(i32 0)'
valid 'INT32_MAX' 'print 2147483647;' 'call void @print_i32(i32 2147483647)'
valid 'INT32_MIN por expresion' 'print 0 - 2147483647 - 1;' '%t2 = sub i32 %t1, 1'
valid 'decimal normal pequeno' "print 0.$(printf '%0306d' 0)1;" 'call void @print_f64(double'
valid 'decimal normal grande' "print 1$(printf '%0308d' 0).0;" 'call void @print_f64(double'
valid 'decimal cerca de DBL_MAX' "print 17976931348623157$(printf '%0292d' 0).0;" '0x7FEFFFFFFFFFFFFF'
valid 'decimal cerca de DBL_MIN normal' "print 0.$(printf '%0307d' 0)22250738585072014;" '0x0010000000000000'
valid 'precedencia y variables' 'let x = 1; let y = x + 2 * 3; print y;' '%t2 = add i32 1, %t1'
valid 'asociatividad de division' 'print 16 / 4 / 2;' '%t2 = sdiv i32 %t1, 2'
valid 'ambos tipos y multiples print' 'let x = 2; let y = 2.5; print x; print y;' 'call void @print_f64(double'
deep=$(awk 'BEGIN { printf "print "; for (i=0;i<200;i++) printf "("; printf "1 + 2"; for (i=0;i<200;i++) printf ")"; print ";" }')
valid '200 parentesis anidados' "$deep" '%t1 = add i32 1, 2'
deep_ops=$(awk 'BEGIN { printf "print "; for (i=0;i<200;i++) printf "1 + ("; printf "1"; for (i=0;i<200;i++) printf ")"; print ";" }')
valid '200 operaciones anidadas' "$deep_ops" '%t200 = add i32'
long=$(printf '%0512d' 0 | tr 0 x)
valid 'identificador largo' "let $long = 2; print $long;" 'call void @print_i32(i32 2)'
many=$(awk 'BEGIN { for (i=0;i<400;i++) printf "let a%d = %d;\n",i,i; print "print a399;" }')
valid '400 declaraciones' "$many" 'call void @print_i32(i32 399)'
valid 'CRLF' "$(printf 'let a = 1;\r\nprint a;\r\n')" 'call void @print_i32(i32 1)'
valid 'LF' "$(printf 'let a = 1;\nprint a;\n')" 'call void @print_i32(i32 1)'
invalid 'entero mayor que i32' 'print 2147483648;' 'fuera de rango'
invalid 'entero demasiado grande' "print $(printf '%050d' 0 | tr 0 9);" 'fuera de rango'
invalid 'decimal muy grande' "print $(printf '%0400d' 0 | tr 0 9).0;" 'fuera de rango'
invalid 'decimal subdesbordado' "print 0.$(printf '%0400d' 0)1;" 'fuera de rango'
invalid 'archivo vacio' '' 'error sintactico'
invalid 'error lexico en linea posterior' "$(printf 'let a = 1;\nprint @;')" ':2:7: error lexico'
invalid 'multiples errores sintacticos: se informa el primero' "$(printf 'let a = ;\nprint +;')" ':1:9: error sintactico'
invalid 'tipos incompatibles' 'let a = 1; print a + 1.0;' 'tipos incompatibles'
invalid 'uso adelantado' 'print a; let a = 1;' 'no declarada'

if ! ./bin/compilador.exe --emit-llvm "$dir/no-existe.olc" -o "$dir/no-existe.ll" > "$dir/out" 2> "$dir/error" &&
   [ ! -e "$dir/no-existe.ll" ]; then pass 'archivo inexistente'
else fail 'archivo inexistente'; fi
if ! ./bin/compilador.exe examples/basico.olc 1>&- 2> "$dir/error" &&
   grep -F 'Error al escribir AST' "$dir/error" >/dev/null; then pass 'error de escritura del AST'
else fail 'error de escritura del AST'; fi

printf 'print 2;\n' > "$dir/hardlink-source.olc"
if ln "$dir/hardlink-source.olc" "$dir/hardlink-output.ll" 2> "$dir/error" &&
   ! ./bin/compilador.exe --emit-llvm "$dir/hardlink-source.olc" -o "$dir/hardlink-output.ll" > "$dir/out" 2> "$dir/error" &&
   grep -F 'mismo archivo' "$dir/error" >/dev/null &&
   grep -F 'print 2;' "$dir/hardlink-source.olc" >/dev/null; then pass 'proteccion ante enlace duro'
else fail 'proteccion ante enlace duro'; fi

printf 'let a = 10; print a / 0;\n' > "$dir/div0.olc"
if ./bin/compilador.exe --emit-llvm "$dir/div0.olc" -o "$dir/div0.ll" 2> "$dir/error" &&
   grep -F 'sdiv i32 10, 0' "$dir/div0.ll" >/dev/null &&
   llvm-as "$dir/div0.ll" -o "$dir/div0.bc" && opt -passes=verify -disable-output "$dir/div0.bc"; then
    pass 'division entera por cero: IR aceptado, resultado indefinido'
else fail 'division entera por cero: IR aceptado, resultado indefinido'; fi
printf 'let a = 10.0; print a / 0.0;\n' > "$dir/fdiv0.olc"
if ./bin/compilador.exe --emit-llvm "$dir/fdiv0.olc" -o "$dir/fdiv0.ll" 2> "$dir/error" &&
   grep -F 'fdiv double' "$dir/fdiv0.ll" >/dev/null &&
   llvm-as "$dir/fdiv0.ll" -o "$dir/fdiv0.bc" && opt -passes=verify -disable-output "$dir/fdiv0.bc"; then
    pass 'division decimal por cero: IR aceptado, ejecucion no verificada'
else fail 'division decimal por cero: IR aceptado, ejecucion no verificada'; fi

for name in enteros decimales mixto; do
    if sh scripts/build_avr.sh "examples/$name.olc" "$dir/$name" > "$dir/out" 2> "$dir/error" &&
       [ -s "$dir/$name/firmware.elf" ] && [ -s "$dir/$name/firmware.hex" ] &&
       [ ! -s "$dir/$name/undefined.txt" ] &&
       grep -F 'avr:6' "$dir/$name/architecture.txt" >/dev/null; then
        pass "extremo a extremo $name"
    else fail "extremo a extremo $name"; fi
done
printf 'print desconocido;\n' > "$dir/bad.olc"
if ! sh scripts/build_avr.sh "$dir/bad.olc" "$dir/rejected" > "$dir/out" 2> "$dir/error" &&
   [ ! -e "$dir/rejected" ] && ! ls "$dir"/rejected.tmp.* >/dev/null 2>&1; then pass 'invalido sin firmware'
else fail 'invalido sin firmware'; fi
mkdir -p "$dir/runtime alternativo"
cp runtime/avr/*.c runtime/avr/*.h "$dir/runtime alternativo/"
if AVR_RUNTIME_DIR="$dir/runtime alternativo" sh scripts/build_avr.sh examples/enteros.olc "$dir/alternate" > "$dir/out" 2> "$dir/error" &&
   [ -s "$dir/alternate/firmware.elf" ]; then pass 'runtime alternativo mediante variable'
else fail 'runtime alternativo mediante variable'; fi
echo "Integrales: $passed aprobadas, $failed fallidas; simulacion y placa: pendientes"
[ "$failed" -eq 0 ]
