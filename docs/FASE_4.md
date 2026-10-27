# Fase 4: generación LLVM IR

## Diseño

El flujo es Flex → Bison → AST → análisis semántico → generación LLVM. El
generador C de `src/codegen/` consume únicamente un AST semánticamente válido
y sus anotaciones de tipos y valores; no vuelve a ejecutar el análisis semántico.
Recorre las instrucciones en orden y las expresiones de forma recursiva.

La función `olc_program` devuelve `void` y no tiene argumentos: es un punto de
entrada propio del programa generado, no el `main` de Windows ni un firmware.
El enunciado no especifica el nombre de entrada ni el ABI concreto del runtime;
la integración futura debe adaptar esta interfaz al soporte del docente. El
módulo no fija target triple ni data layout: la selección AVR se hace
explícitamente con `llc`. Esto permite verificar el IR independientemente del
destino, sin afirmar que su ABI coincida con la del runtime.

El módulo contiene declaraciones `declare void @print_i32(i32)` y
`declare void @print_f64(double)`, un bloque `entry` y `ret void`. No define
estas funciones. Cada binaria recibe un temporal SSA único `%t1`, `%t2`, etc.,
en orden determinista. Las variables de asignación única se asocian en una tabla
local de generación al operando producido por su inicialización; no se generan
`alloca`, `load` ni `store`.

| Operador | Entero (`i32`) | Decimal (`double`) |
|---|---|---|
| + | `add` | `fadd` |
| - | `sub` | `fsub` |
| * | `mul` | `fmul` |
| / | `sdiv` | `fdiv` |

Los literales enteros usan el valor validado. Los decimales usan una
representación hexadecimal LLVM de los 64 bits del `double` anotado, obtenida
con `memcpy`; así se conserva el valor exacto sin depender de separadores
decimales regionales. La compilación exige un `double` binario de 64 bits con
las propiedades de precisión y exponente de IEEE 754 binary64.

## Interfaz y archivos de salida

En UCRT64, desde la raíz:

```sh
make clean
make
make test
./bin/compilador.exe examples/basico.olc
./bin/compilador.exe --parse-only examples/basico.olc
./bin/compilador.exe --emit-llvm examples/basico.olc -o build/basico.ll
```

La ejecución normal valida semántica y muestra el AST; `--parse-only`
solo revisa sintaxis. `--emit-llvm` valida semántica y genera un archivo sin
imprimir el AST. Si el análisis falla, no toca el archivo de salida existente.
El generador escribe primero un archivo temporal exclusivo junto al destino,
comprueba la escritura y cierre, y luego reemplaza el destino mediante
`MoveFileExA` en Windows. Ante errores se intenta eliminar el temporal y se
conserva el destino anterior; se rechaza usar como salida el mismo archivo de
entrada. La implementación de publicación del archivo usa la API de Windows.

Los ejemplos `examples/{enteros,decimales,mixto}.olc` y sus archivos en
`examples/llvm/` se generaron con el propio compilador. La suite vuelve a
generarlos y comprueba que coincidan con los archivos entregables.
Por ejemplo, el programa entero genera:

```llvm
%t1 = add i32 10, 20
%t2 = sub i32 20, 5
%t3 = mul i32 %t1, %t2
call void @print_i32(i32 %t3)
```

## Verificación y AVR

En CLANG64, después de generar los ejemplos:

```sh
llvm-as examples/llvm/enteros.ll -o build/enteros.bc
llvm-dis build/enteros.bc -o build/enteros_recuperado.ll
opt -passes=verify -disable-output build/enteros.bc
llc -mtriple=avr -mcpu=atmega2560 -filetype=asm build/enteros.bc -o build/enteros.S
avr-gcc -mmcu=atmega2560 -c build/enteros.S -o build/enteros.o
llvm-as examples/llvm/decimales.ll -o build/decimales.bc
opt -passes=verify -disable-output build/decimales.bc
llc -mtriple=avr -mcpu=atmega2560 -filetype=asm build/decimales.bc -o build/decimales.S
avr-gcc -mmcu=atmega2560 -c build/decimales.S -o build/decimales.o
avr-nm --undefined-only build/enteros.o
avr-nm --undefined-only build/decimales.o
```

Con LLVM 23.1.4 de MSYS2 CLANG64, los ejemplos entero y decimal pasaron
`llvm-as` y `opt -passes=verify`; el entero también pasó la ida y vuelta por
`llvm-dis`. Ambos produjeron ensamblador ATmega2560 y objetos `elf32-avr`
con AVR-GCC. `avr-nm` mostró `print_i32` y `print_f64` respectivamente como
símbolos externos sin resolver, como se espera antes de enlazar el runtime.
El backend puede plegar expresiones constantes, por lo que estas pruebas no
demuestran el funcionamiento general de operaciones decimales en la placa.

La configuración predeterminada de este AVR-GCC informó `__SIZEOF_DOUBLE__ 4`,
`__DBL_MANT_DIG__ 24` y `-mdouble=32`; el IR exige `double` de 64 bits.
Por ello no se ha demostrado compatibilidad de argumentos con una función
`print_f64` compilada con esa configuración. Es necesario acordar y verificar
la ABI, el punto de entrada, bibliotecas auxiliares y runtime facilitados por el
docente; no se convierte silenciosamente el IR a `float`. No se enlazó un
firmware, no se cargó ni se ejecutó en placa. La fase siguiente deberá resolver
esas integraciones y pruebas sin asumir que un objeto AVR demuestra ejecución.

## Pruebas

`make test` ejecuta las 18 pruebas sintácticas anteriores, las 26 semánticas y
la suite `tests/test_codegen.sh`. Esta última usa las herramientas de
`/clang64/bin` por defecto; puede configurarse mediante `LLVM_BIN`. Cada caso
válido de generación se ensambla con `llvm-as` y se verifica con `opt`; la
suite también comprueba determinismo, protección de salidas, ejemplos
reproducibles y las dos pruebas AVR. Los archivos de compilación y prueba quedan
en `build/`, ignorado por Git.

En la compilación limpia final se aprobaron 18 pruebas sintácticas, 26
semánticas y 34 de generación/LLVM/AVR, con cero fallidas. Bison generó el
parser sin conflictos shift/reduce ni reduce/reduce.
