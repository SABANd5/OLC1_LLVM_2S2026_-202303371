# Fase 2: lexer, parser y AST

## Archivos

- `src/lexer/lexer.l`: reglas Flex, ubicación y errores léxicos.
- `src/parser/parser.y`: gramática Bison, construcción del AST y errores sintácticos.
- `src/ast/ast.h` y `src/ast/ast.c`: tipos, constructores, impresión y liberación del árbol.
- `src/main.c`: abre el archivo, ejecuta el análisis, muestra el AST y libera recursos.
- `Makefile`: generación, compilación, pruebas y limpieza.
- `examples/basico.olc`: ejemplo válido. `tests/run_tests.sh`: pruebas automatizadas.

## Reglas léxicas

Se reconocen las palabras reservadas exactas `let` y `print`, identificadores,
literales enteros y decimales, `+ - * / = ( ) ;` y separadores: espacio,
tabulación, CR y LF. Las palabras son sensibles a mayúsculas. Por elección
simple, un identificador comienza con letra ASCII o `_` y continúa con letras
ASCII, dígitos o `_`. Por la regla de coincidencia más larga, `letter` y
`print1` son identificadores, mientras que `let` y `print` son palabras
reservadas. Un entero consiste en uno o más dígitos; un decimal exige dígitos
a ambos lados del punto, por ejemplo `25.5`. No se reconocen notación
exponencial, comentarios ni signos como parte del literal. Los literales se
conservan como texto: su rango y valor no se validan en esta fase.

Un carácter no reconocido produce un diagnóstico con archivo, línea y columna,
y el proceso finaliza con estado distinto de cero. Las líneas y columnas son
de base 1; la tabulación cuenta como un carácter y CRLF cuenta como un salto de
línea. El fin de archivo también tiene una ubicación para los errores de sintaxis.

## Gramática

```text
programa      : instrucciones
instrucciones : instrucciones instruccion | instruccion
instruccion   : LET ID '=' expresion ';' | PRINT expresion ';'
expresion     : expresion '+' termino | expresion '-' termino | termino
termino       : termino '*' factor | termino '/' factor | factor
factor        : ENTERO | DECIMAL | ID | '(' expresion ')'
```

La recursión izquierda de `expresion` y `termino` da asociatividad izquierda.
Las producciones de `termino` quedan anidadas en `expresion`, por lo que `*` y
`/` tienen mayor precedencia que `+` y `-`; los paréntesis fuerzan agrupación.
No se utilizan directivas de precedencia de Bison. `-Werror=conflicts-sr` y
`-Werror=conflicts-rr` hacen fallar la generación si aparecen conflictos; el
informe de estados queda en `build/parser.output`.

La gramática requiere al menos una instrucción, por lo que el archivo vacío se
rechaza. Los errores de sintaxis incluyen ubicación y un mensaje descriptivo de
Bison; tras un error léxico o sintáctico no se muestra un AST exitoso.

## AST y memoria

`AstNode` incluye clase de nodo, ubicación inicial y final y un enlace para la
siguiente instrucción. El programa contiene una lista de instrucciones. `let`
guarda nombre y expresión; `print`, una expresión; la operación binaria, operador
y dos operandos; enteros, decimales e identificadores guardan su texto original.
Las expresiones entre paréntesis no crean un nodo adicional: modifican la
agrupación del árbol. Desde la Fase 3 se conserva la ubicación de los tokens
interiores para que los diagnósticos señalen el identificador u operador. La impresión muestra una
línea por nodo con indentación que expresa la jerarquía.

Los constructores toman propiedad de sus argumentos. Los destructores de Bison
liberan valores descartados si ocurre un error; el programa libera el árbol
completo al finalizar. Si falla una asignación de memoria, el proceso termina
con un diagnóstico de memoria insuficiente.

## Construcción y ejecución

En una terminal MSYS2 UCRT64, desde la raíz del repositorio:

```sh
make clean
make
./bin/compilador.exe examples/basico.olc
make test
```

Se necesitan GCC C11, Make, Flex y Bison. Los archivos generados van en `build/`
y `bin/`, ignorados por Git. `make clean` elimina ambos directorios, incluidos
otros archivos generados que se hayan guardado allí.

## Validación y límites

Se generaron el lexer y el parser, se compilaron los archivos C y se enlazó el
ejecutable en UCRT64. `make test` pasó 18 casos y falló 0: los 15 solicitados y
tres adicionales para CRLF/tabulación, ubicación en segunda línea y decimal
incompleto. Las pruebas comparan el AST completo para las entradas válidas y
comprueban que las entradas inválidas fallen sin imprimir el árbol. Se normaliza
CRLF en la salida antes de compararla en Windows. El informe de Bison no muestra
conflictos: 0 shift/reduce y 0 reduce/reduce.

Esta fase valida sintaxis, no significado: acepta identificadores sin declarar,
declaraciones duplicadas, mezclas de tipos y literales fuera de rango. No incluye
tabla de símbolos, análisis semántico, generación LLVM IR ni runtime. Estos
comportamientos pendientes no constituyen validación semántica exitosa.
