# Fase 3: análisis semántico y tabla de símbolos

## Arquitectura

El flujo normal es archivo → Flex → Bison → AST → análisis semántico →
impresión del AST, solo si el programa es válido. `src/semantic/semantic.c` y
`semantic.h` implementan la fase independiente; `src/main.c` no la ejecuta si
falló el análisis léxico o sintáctico. Para estudiar solo la sintaxis se conserva
`./bin/compilador.exe --parse-only archivo.olc`; este modo no valida la semántica.

## Tabla de símbolos y vida útil

La tabla global es una lista enlazada en C. Cada entrada contiene nombre, tipo,
ubicación del identificador declarado y referencia al nodo de declaración. La
búsqueda es lineal. Nombres y nodos pertenecen al AST; la tabla los usa prestados,
se libera al terminar el análisis y no deja punteros desde el AST hacia ella. El
AST sigue siendo dueño de sus datos y se libera al finalizar el programa.

Las anotaciones `SemanticType` en nodos del AST son `TYPE_UNKNOWN`,
`TYPE_ERROR`, `TYPE_INTEGER` y `TYPE_DECIMAL`. Una declaración y un `print`
válidos conservan el tipo de su expresión; cada expresión conserva el propio.
Los literales válidos guardan además un `int32_t` o `double`, y conservan su
texto original. Esto prepara la generación posterior sin crear aún LLVM IR.

## Algoritmo y reglas

Las instrucciones se recorren en orden. Para cada `let`, se comprueba si el
nombre ya está registrado, se analiza su expresión y se registra solamente si
esta es válida y no hay duplicación. Por ello, una variable no está disponible
en su propia inicialización ni antes de declararse. Los `print` analizan su
expresión. Se continúa analizando instrucciones posteriores para reportar más
de un error; un tipo erróneo se propaga y evita mensajes derivados innecesarios.

Los identificadores adquieren el tipo de su declaración. Cada operación binaria
requiere operandos del mismo tipo y conserva ese tipo para `+`, `-`, `*` y `/`.
La división entera sigue siendo entera: en una fase posterior corresponderá a
`sdiv`. No hay conversiones implícitas. Por ejemplo:

```text
let a = 10;
let b = a + 2;
print b;
```

es válido; `print a + 2.5;` produce error de tipos incompatibles. También se
rechazan nombres no declarados, declaraciones duplicadas y literales fuera de
rango. Los diagnósticos muestran archivo, línea, columna y explicación; la
duplicación indica además la ubicación de la primera declaración. Se conserva
la ubicación real del identificador u operador incluso entre paréntesis.

Los enteros se convierten con `strtoimax` y deben estar en el rango de `i32`.
La gramática actual no incluye unario negativo: los literales aceptados van de
0 a 2147483647, aunque expresiones como `0 - 1` son sintácticamente válidas.
Los decimales se convierten con `strtod` y deben ser finitos; se rechaza
`ERANGE`, tanto desbordamiento como subdesbordamiento reportado por la biblioteca
C. El proceso usa la localidad C inicial y punto decimal. No se calculan ni se
validan valores resultantes de operaciones durante el análisis semántico.

## Compilación y pruebas

Desde la raíz en MSYS2 UCRT64:

```sh
make clean
make
make test
./bin/compilador.exe examples/basico.olc
```

`tests/run_tests.sh` conserva los 18 casos de sintaxis de Fase 2 usando
`--parse-only`. `tests/test_semantic.sh` comprueba casos válidos e inválidos,
diagnósticos y códigos de salida. `tests/semantic_types.c` verifica directamente
las anotaciones de tipos y valores en el AST. La generación de Bison trata ambos
tipos de conflicto como errores y escribe `build/parser.output`.

La validación limpia final aprobó las 18 pruebas sintácticas y 26 semánticas,
con 0 fallidas y 0 conflictos shift/reduce o reduce/reduce. No se incluyen
generación LLVM, evaluación aritmética, comprobaciones de
división por cero, runtime, firmware ni prueba en placa. La compatibilidad entre
el `double` de LLVM y la ABI/runtime AVR requiere validación en una fase posterior.
