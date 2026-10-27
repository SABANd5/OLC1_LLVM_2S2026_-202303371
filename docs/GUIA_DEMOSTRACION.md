# Guía reproducible de demostración

Ejecute desde la raíz en MSYS2. UCRT64 se usa para construir el compilador;
CLANG64 proporciona las herramientas LLVM y AVR. El material es para practicar
la explicación; la ejecución en placa solo podrá afirmarse después de hacerla.

## 1. Estructura, lexer y gramática

~~~sh
ls src/ast src/lexer src/parser src/semantic src/codegen
cat src/lexer/lexer.l
cat src/parser/parser.y
make clean
make
if grep -iE 'conflicts:|conflict on' build/parser.output; then
    echo 'Revisar conflictos'
else
    echo 'Sin conflictos reportados'
fi
~~~

Explique cómo Flex distingue let y print de los identificadores y cómo los
niveles expresion, termino y factor establecen precedencia. La generación de
Bison falla si hay conflictos shift/reduce o reduce/reduce.

## 2. Programa válido, AST y error semántico

~~~sh
cat examples/mixto.olc
./bin/compilador.exe examples/mixto.olc
printf 'let a = 10; print a + 2.5;\n' > build/error_semantico.olc
./bin/compilador.exe build/error_semantico.olc
echo "Estado de salida: $?"
~~~

El programa válido muestra Programa, Let y Print, con nodos Binaria para cada
operación. El inválido informa tipos incompatibles en + y devuelve estado no
cero, sin mostrar un AST exitoso. Si el shell tiene activado errexit, desactívelo
antes de ejecutar intencionalmente el caso inválido.

## 3. Generación y verificación LLVM

En CLANG64, desde la misma raíz:

~~~sh
./bin/compilador.exe --emit-llvm examples/mixto.olc -o build/demo.ll
cat build/demo.ll
llvm-as build/demo.ll -o build/demo.bc
llvm-dis build/demo.bc -o build/demo_recuperado.ll
opt -passes=verify -disable-output build/demo.bc
~~~

Los comandos LLVM terminan con estado cero si la verificación pasa. Busque
add y sdiv con i32, fadd y fmul con double, temporales %t1–%t4 y llamadas a
print_i32 y print_f64. Las declaraciones y la función olc_program forman un
módulo completo; la verificación no ejecuta sus funciones.

## 4. AVR, símbolos y ABI

~~~sh
sh scripts/build_avr.sh examples/mixto.olc build/avr/demo
avr-objdump -f build/avr/demo/firmware.elf
avr-nm --undefined-only build/avr/demo/firmware.elf
avr-nm build/avr/demo/firmware.elf | grep -E 'olc_program|print_i32|print_f64'
avr-size -C --mcu=atmega2560 build/avr/demo/firmware.elf
printf '' | avr-gcc -mmcu=atmega2560 -mdouble=64 -dM -E - | grep -E '__SIZEOF_DOUBLE__|__DBL_MANT_DIG__'
avr-gcc -mmcu=atmega2560 -mdouble=64 -print-multi-directory
~~~

El directorio build/avr/demo debe ser nuevo; si ya existe, use otro nombre o
ejecute make clean antes de reconstruir. Se espera elf32-avr y arquitectura
avr:6, ningún símbolo indefinido impreso, las tres funciones listadas, double
de 8 bytes, mantisa de 53 bits y multilib avr6/double64. En la última construcción
mixta se observaron 3532 bytes de programa y 24 bytes de datos estáticos; estos
tamaños pueden cambiar con las herramientas.

Explique que la sonda estática observó el paso de double en r18–r25 para las
firmas probadas, pero que esto no valida por sí solo la ABI del runtime oficial.
El runtime incluido configura USART0 y proporciona impresiones provisionales;
el docente proporcionará los archivos y la placa. No se ha observado una salida
serial física ni se ha probado el firmware en simulador.
