# Documentación técnica

## Descripción general

Este proyecto implementa en C11 un compilador para declaraciones de asignación
única y expresiones aritméticas. Flex reconoce tokens, Bison construye un AST,
el análisis semántico verifica símbolos y tipos, y un recorrido del AST genera
LLVM IR textual. El backend de LLVM transforma el IR para AVR. El compilador
es un ejecutable anfitrión; el firmware para la placa es un resultado distinto.

Se aceptan let y print, enteros, decimales,
identificadores ya declarados, paréntesis y +, -, *, /. No se admiten
conversiones implícitas, reasignaciones, ámbitos adicionales ni construcciones
de control. La extensión solicitada en Fase 9 añade únicamente
led 13 on; para Mega 2560. No figura en el PDF original; el cambio de
demostración fue comunicado por el estudiante y no se ha verificado por separado.

## Instrucciones para compilar y ejecutar

En Windows 11 con MSYS2 UCRT64, GCC C11, Make, Flex y Bison:

~~~sh
make clean
make
./bin/compilador.exe examples/mixto.olc
./bin/compilador.exe --parse-only examples/mixto.olc
./bin/compilador.exe --emit-llvm examples/mixto.olc -o build/mixto.ll
make test
~~~

La primera ejecución valida semántica y muestra el AST; --parse-only omite la
semántica. --emit-llvm requiere análisis semántico exitoso. Los errores se
escriben en stderr con ubicación y provocan una salida distinta de cero. Si
fallan el análisis o la generación, no se presenta una salida parcial como
resultado exitoso y se conserva una salida previa. El script AVR exige un
directorio de salida nuevo. make clean elimina build y bin.

## Estructura del proyecto

~~~text
src/
  main.c             programa anfitrión
  lexer/lexer.l      reglas Flex
  parser/parser.y    gramática Bison
  ast/               nodos, recorridos y liberación
  semantic/          tipos y símbolos
  codegen/           generación LLVM textual
examples/            programas y ejemplos LLVM generados
tests/               suites y sondas de ABI
runtime/avr/         runtime provisional para Mega
scripts/build_avr.sh construcción AVR provisional
docs/                documentación por fase y guías
build/, bin/         artefactos generados, ignorados por Git
~~~

## Uso de Flex y Bison

Flex reconoce las palabras exactas let, print, led y on, identificadores ASCII,
enteros, decimales, operadores y delimitadores. Un identificador empieza con
letra ASCII o guion bajo; continúa con letras, dígitos o guion bajo. Un entero
es una secuencia de dígitos; un decimal requiere dígitos antes y después del
punto. Los espacios, tabulaciones y saltos LF/CRLF son separadores. Un carácter
no reconocido produce un error léxico con línea y columna.

Bison recibe los tokens, aplica la gramática y crea nodos AST en sus acciones.
Las ubicaciones se conservan para los diagnósticos. Las reglas de destrucción
liberan valores descartados al ocurrir errores. Make ejecuta Bison con
-Werror=conflicts-sr y -Werror=conflicts-rr y genera build/parser.output.

## Gramática utilizada y eliminación de ambigüedad

~~~text
programa      : instrucciones
instrucciones : instrucciones instruccion | instruccion
instruccion   : LET ID '=' expresion ';' | PRINT expresion ';'
              | LED ENTERO ON ';'
expresion     : expresion '+' termino | expresion '-' termino | termino
termino       : termino '*' factor | termino '/' factor | factor
factor        : ENTERO | DECIMAL | ID | '(' expresion ')'
~~~

Los niveles expresion, termino y factor fijan precedencia: multiplicación y
división se agrupan antes que suma y resta. La recursión izquierda establece
asociatividad izquierda. Los paréntesis fuerzan agrupación. No se usan
directivas de precedencia de Bison; la generación verificada presenta cero
conflictos shift/reduce y reduce/reduce. La gramática exige al menos una
instrucción, por lo que el archivo vacío es inválido.

## Representación del AST

AstNode contiene clase, ubicación, tipo semántico, valor literal validado y
enlace a la siguiente instrucción. Hay nodos programa, declaración, impresión,
operación binaria, entero, decimal, identificador y LED. El nodo LED conserva
el texto del pin y el estado; semántica solo acepta el texto 13 y on. El nodo binario guarda
operador e hijos; un programa contiene una lista de instrucciones. Los
paréntesis modifican la agrupación sin crear un nodo adicional. Los constructores
reciben la propiedad de sus argumentos y ast_free libera el árbol.

## Análisis semántico

Se recorre el programa en orden con un único entorno global. La tabla enlazada
registra nombre, tipo, ubicación y nodo de declaración. Una declaración se
registra solo después de validar su inicialización, por lo que una referencia
adelantada o autorreferencia falla. También se detectan duplicados y operaciones
entre tipos distintos. Cada expresión y cada let o print válido conserva su
tipo en el AST. No se realizan conversiones implícitas.

Los literales enteros se comprueban como i32; como la gramática no tiene
negación unaria, el mínimo se representa mediante una expresión, por ejemplo
0 - 2147483647 - 1. Los decimales se convierten con strtod a double y se
rechazan errores de rango. La fase semántica no evalúa expresiones ni valida
división por cero.

## Generación de LLVM IR

El generador recorre el AST validado. Entero se representa como i32 con add,
sub, mul y sdiv; decimal como double con fadd, fsub, fmul y fdiv. Cada operación
crea un temporal SSA distinto. Los nombres de variables se asocian al operando
LLVM de su inicialización, sin reservar memoria para variables inmutables.
Los literales double se escriben como bits hexadecimales de 64 bits.

El módulo declara print_i32(i32) y print_f64(double), define
void @olc_program() con un bloque entry y termina con ret void. No implementa
las funciones de impresión ni fija target triple. El nombre olc_program es una
elección provisional para integrar un punto de entrada; debe comprobarse con
el runtime docente. La salida se escribe primero en un archivo temporal y se
publica solo al completar la generación.
Si existe una instrucción LED válida, declara y llama a
void @olc_led13_on(); esta función del runtime configura DDRB7 y PORTB7.

## Arquitectura asignada

202303371 mod 3 = 0: Arduino Mega 2560, AVR/ATmega2560. Las sondas de Fase 5
muestran coincidencia estática de registros para las firmas probadas entre
LLVM y AVR-GCC con -mdouble=64. El AVR-GCC instalado usa double de 32 bits
por defecto; usar esa configuración con print_f64(double) de LLVM no está
validado. El ABI del runtime docente todavía se desconoce.

## Proceso para generar el código de la arquitectura

Con LLVM y herramientas AVR de MSYS2 CLANG64 disponibles:

~~~sh
sh scripts/build_avr.sh examples/mixto.olc build/avr/mixto
avr-nm --undefined-only build/avr/mixto/firmware.elf
avr-objdump -f build/avr/mixto/firmware.elf
avr-size -C --mcu=atmega2560 build/avr/mixto/firmware.elf
~~~

El directorio de salida no debe existir. El script genera IR, verifica con
llvm-as y opt, ejecuta llc para avr/atmega2560, ensambla, compila runtime y
main provisionales con -mdouble=64, enlaza ELF y convierte a Intel HEX. La
construcción validada usa USART0, 16 MHz y 115200 baudios nominales. La variable
AVR_RUNTIME_DIR permite otro directorio con la misma organización de archivos;
esto no adapta automáticamente el runtime del docente.

## Ejemplo de entrada y resultado esperado

Entrada: [examples/mixto.olc](examples/mixto.olc), con variables enteras y
decimales, y dos print. El AST contiene primero la suma y división enteras y
después suma y multiplicación decimales. El IR generado está en
[examples/llvm/mixto.ll](examples/llvm/mixto.ll), con estos fragmentos:

~~~llvm
%t1 = add i32 8, 4
%t2 = sdiv i32 %t1, 2
%t3 = fadd double 0x3FB999999999999A, 0x4004000000000000
%t4 = fmul double %t3, 0x4008000000000000
call void @print_i32(i32 %t2)
call void @print_f64(double %t4)
~~~

El resultado matemático esperado es 6 y aproximadamente 7.8; esa salida no se
ha observado en una placa ni con el runtime docente.

## Pruebas y limitaciones

La suite comprende 18 pruebas sintácticas, 26 semánticas, 34 de LLVM, 24 de
AVR, 35 integrales y 17 de LED. Las verificaciones anteriores están en
[docs/FASE_6.md](docs/FASE_6.md). LLVM acepta los ejemplos y el enlace
provisional produce ELF y HEX; no se ha ejecutado simulación ni hardware.
La división entera por cero y INT32_MIN dividido entre -1 producen
comportamiento indefinido en LLVM; no se ha añadido validación semántica para
ello. El runtime provisional imprime double con tres decimales y tiene límites
documentados; no sustituye el runtime oficial.
El LED y la carga física no han sido comprobados en placa; consulte
[docs/FASE_9_LED_ARDUINO.md](docs/FASE_9_LED_ARDUINO.md).

El PDF requiere un ensayo individual en PDF de máximo dos páginas, escrito por
el estudiante sin IA generativa. Está pendiente de incorporación por su autor.
