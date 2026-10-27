#!/bin/sh
set -u
dir=build/test-fase2
mkdir -p "$dir"
passed=0
failed=0

valid() {
    name=$1 input=$2 expected=$3
    printf '%s\n' "$input" > "$dir/input.olc"
    printf '%s\n' "$expected" > "$dir/expected.txt"
    if ./bin/compilador.exe --parse-only "$dir/input.olc" > "$dir/actual.txt" 2> "$dir/error.txt" &&
       tr -d '\r' < "$dir/actual.txt" > "$dir/normalized.txt" &&
       diff -u "$dir/expected.txt" "$dir/normalized.txt" && [ ! -s "$dir/error.txt" ]; then
        echo "OK: $name"; passed=$((passed + 1))
    else
        echo "FALLO: $name"; cat "$dir/error.txt"; failed=$((failed + 1))
    fi
}

invalid() {
    name=$1 input=$2 pattern=$3
    printf '%s' "$input" > "$dir/input.olc"
    if ./bin/compilador.exe --parse-only "$dir/input.olc" > "$dir/actual.txt" 2> "$dir/error.txt"; then
        echo "FALLO: $name (se acepto entrada invalida)"; failed=$((failed + 1))
    elif [ ! -s "$dir/actual.txt" ] && grep -E "$pattern" "$dir/error.txt" >/dev/null; then
        echo "OK: $name"; passed=$((passed + 1))
    else
        echo "FALLO: $name (diagnostico o salida incorrectos)"; cat "$dir/error.txt"; failed=$((failed + 1))
    fi
}

valid 'declaracion de entero' 'let x = 10;' 'Programa
  Let x
    Entero 10'
valid 'declaracion de decimal' 'let precio = 25.5;' 'Programa
  Let precio
    Decimal 25.5'
valid 'print' 'print 8;' 'Programa
  Print
    Entero 8'
valid 'multiples instrucciones' 'let x = 1; print x;' 'Programa
  Let x
    Entero 1
  Print
    Identificador x'
valid 'precedencia multiplicacion' 'print 1 + 2 * 3;' 'Programa
  Print
    Binaria +
      Entero 1
      Binaria *
        Entero 2
        Entero 3'
valid 'asociatividad resta' 'print 8 - 3 - 1;' 'Programa
  Print
    Binaria -
      Binaria -
        Entero 8
        Entero 3
      Entero 1'
valid 'asociatividad division' 'print 8 / 4 / 2;' 'Programa
  Print
    Binaria /
      Binaria /
        Entero 8
        Entero 4
      Entero 2'
valid 'parentesis' 'print (1 + 2) * 3;' 'Programa
  Print
    Binaria *
      Binaria +
        Entero 1
        Entero 2
      Entero 3'
valid 'identificadores y palabras reservadas' 'let letter_1 = 2; print letter_1;' 'Programa
  Let letter_1
    Entero 2
  Print
    Identificador letter_1'
invalid 'caracter invalido y ubicacion' 'print @;' ':1:7: error lexico:'
invalid 'falta punto y coma' 'let x = 1' ':1:10: error sintactico:'
invalid 'parentesis sin cerrar' 'print (1 + 2;' 'error sintactico:'
invalid 'declaracion incompleta' 'let x = ;' 'error sintactico:'
invalid 'archivo vacio' '' ':1:1: error sintactico:'
if ./bin/compilador.exe --parse-only "$dir/archivo-inexistente.olc" > "$dir/actual.txt" 2> "$dir/error.txt"; then
    echo 'FALLO: archivo inexistente (aceptado)'; failed=$((failed + 1))
elif [ ! -s "$dir/actual.txt" ] && grep -F 'archivo-inexistente.olc' "$dir/error.txt" >/dev/null; then
    echo 'OK: archivo inexistente'; passed=$((passed + 1))
else
    echo 'FALLO: archivo inexistente (diagnostico)'; failed=$((failed + 1))
fi

valid 'saltos de linea y tabulacion' "$(printf 'let\tx = 1;\r\nprint x;')" 'Programa
  Let x
    Entero 1
  Print
    Identificador x'
invalid 'error lexico en segunda linea' "$(printf 'let x = 1;\nprint @;')" ':2:7: error lexico:'
invalid 'decimal sin parte fraccionaria' 'print 1.;' ':1:8: error lexico:'

echo "Resultado: $passed aprobadas, $failed fallidas"
[ "$failed" -eq 0 ]
