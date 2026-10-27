#!/bin/sh
set -u
dir=build/test-fase3
mkdir -p "$dir"
passed=0
failed=0

valid() {
    name=$1 input=$2
    printf '%s\n' "$input" > "$dir/input.olc"
    if ./bin/compilador.exe "$dir/input.olc" > "$dir/out" 2> "$dir/err" &&
       grep -q '^Programa' "$dir/out" && [ ! -s "$dir/err" ]; then
        echo "OK: $name"; passed=$((passed + 1))
    else
        echo "FALLO: $name"; cat "$dir/err"; failed=$((failed + 1))
    fi
}

invalid() {
    name=$1 input=$2 pattern=$3
    printf '%s\n' "$input" > "$dir/input.olc"
    if ./bin/compilador.exe "$dir/input.olc" > "$dir/out" 2> "$dir/err"; then
        echo "FALLO: $name (se acepto)"; failed=$((failed + 1))
    elif [ ! -s "$dir/out" ] && grep -E "$pattern" "$dir/err" >/dev/null; then
        echo "OK: $name"; passed=$((passed + 1))
    else
        echo "FALLO: $name (salida o diagnostico)"; cat "$dir/err"; failed=$((failed + 1))
    fi
}

valid 'declaracion entero' 'let a = 10;'
valid 'declaracion decimal' 'let a = 25.5;'
valid 'uso de identificador' 'let a = 10; let b = a; print b;'
valid 'operaciones enteras' 'print 8 + 6 - 3 * 2 / 1;'
valid 'operaciones decimales' 'print 8.0 + 6.0 - 3.0 * 2.0 / 1.0;'
valid 'operaciones anidadas' 'let a = 1; print (a + 2) * (3 - 1);'
invalid 'variable no declarada' 'print x;' ':1:7: error semantico: variable '\''x'\'' no declarada'
invalid 'declaracion duplicada' 'let a = 10; let a = 20;' 'error semantico: declaracion duplicada de '\''a'\''.*1:5'
invalid 'tipos incompatibles' 'let a = 10; let b = 2.5; let c = a + b;' 'tipos incompatibles.*entero y decimal'
invalid 'referencia antes de declaracion' 'let b = a + 2; let a = 10;' 'variable '\''a'\'' no declarada'
invalid 'autorreferencia' 'let a = a + 1;' 'variable '\''a'\'' no declarada'
valid 'print entero' 'print 10;'
valid 'print decimal' 'print 10.5;'
invalid 'print incompatible' 'let a = 10; print a + 2.5;' 'tipos incompatibles'
valid 'declaraciones consecutivas' 'let a = 1; let b = a + 2; let c = b * a; print c;'
invalid 'entero fuera de i32' 'print 2147483648;' 'literal entero fuera de rango i32'
huge=$(printf '%0400d' 0 | tr 0 9)
invalid 'decimal fuera de double' "print $huge.0;" 'literal decimal fuera de rango double'
invalid 'ubicacion en linea posterior' "$(printf 'let a = 1;\nprint a + 2.5;')" ':2:9: error semantico: tipos incompatibles'
valid 'division entera' 'let a = 8 / 2; print a / 2;'
invalid 'codigo de salida y ausencia de AST' 'print missing;' 'variable '\''missing'\'' no declarada'
valid 'limite entero maximo' 'print 2147483647;'
invalid 'operacion decimal entero' 'print 1.0 * 2;' 'decimal y entero'
invalid 'inicializacion fallida no declara' 'let a = missing; print a;' 'variable '\''a'\'' no declarada'
invalid 'sintaxis rechazada por ruta normal' 'let a = ;' 'error sintactico'
invalid 'identificador entre parentesis conserva ubicacion' 'print (x);' ':1:8: error semantico: variable'

if ./build/semantic_types.exe; then
    echo 'OK: tipos y valores anotados en AST'; passed=$((passed + 1))
else
    echo 'FALLO: tipos y valores anotados en AST'; failed=$((failed + 1))
fi
echo "Semantica: $passed aprobadas, $failed fallidas"
[ "$failed" -eq 0 ]
