# Fase 6: validación integral y preparación AVR

## Auditoría

Se revisaron lexer, parser, AST, análisis semántico, generación LLVM, scripts,
runtime y documentación anterior, partiendo de main sincronizada en 28a1512.
El lenguaje no se amplió.

| Severidad | Hallazgo | Estado y acción |
|---|---|---|
| Alta | sdiv entero por cero y INT32_MIN / -1 tienen comportamiento indefinido. | Pendiente: el PDF no exige una regla adicional; no se promete un resultado. |
| Alta | No están disponibles la ABI, el formato y la entrada del runtime docente. | Bloqueado por soporte docente y prueba en simulador o placa. |
| Media | La salida del AST no comprobaba fallos de escritura. | Corregido con fflush y prueba con stdout cerrado. |
| Media | Si fallaba la consulta de identidad del destino, el generador asumía que era distinto de la entrada. | Corregido: se rechaza cuando no puede verificarse; probado con enlace duro. |
| Media | El script AVR fijaba el directorio del runtime provisional. | Corregido: AVR_RUNTIME_DIR permite seleccionar otro de igual estructura. |
| Media | Expresiones recursivas muy profundas pueden agotar pila; las listas tienen búsquedas lineales. | Parcial: pasan 200 operaciones y 400 declaraciones, sin garantía para tamaños arbitrarios. |
| Baja | El parser aborta al primer error sintáctico; strtod rechaza ERANGE, incluso subdesbordamiento. | Comportamiento documentado; no se añadió recuperación ni extensión del lenguaje. |
| Baja | El enlazador AVR advierte que _exit.o carece de .note.GNU-stack. | Advertencia de biblioteca instalada; enlace exitoso, sin afirmar ejecución. |

El script conserva el runtime provisional por defecto. Puede seleccionarse otro
directorio que contenga format.c, uart.c, main.c y runtime.h mediante
AVR_RUNTIME_DIR. Desde la Fase 9 también se requiere led.c. Esto no adapta automáticamente el runtime docente ni demuestra
compatibilidad con él.

## División por cero y límites

Para la fuente let a = 10; print a / 0; el compilador emite sdiv i32 10, 0.
llvm-as y opt -passes=verify lo aceptan estructuralmente, pero la
[referencia LLVM](https://llvm.org/docs/LangRef.html#sdiv-instruction) define
comportamiento indefinido para divisor cero y para INT32_MIN / -1. La aceptación
del IR no demuestra un resultado correcto en AVR.

Para let a = 10.0; print a / 0.0; se emite fdiv double y LLVM verifica el módulo;
no se ha ejecutado en AVR. La especificación LLVM define fdiv en el entorno de
coma flotante predeterminado. No se añadió una regla semántica no especificada
por el PDF ni un evaluador constante.

Las 35 pruebas nuevas incluyen cero, INT32_MAX, INT32_MIN representado mediante
0 - 2147483647 - 1 (sin literal negativo), enteros fuera de rango, decimales
normales cercanos a DBL_MIN y DBL_MAX, desbordamiento y subdesbordamiento,
200 paréntesis y 200 operaciones anidadas, 400 declaraciones, identificador de
512 caracteres, LF/CRLF, archivo vacío o inexistente, error léxico posterior,
errores sintácticos múltiples (se informa el primero), mezcla de tipos y uso
adelantado.

## Memoria y robustez

Los constructores del AST son propietarios de cadenas y nodos; los destructores
de Bison liberan valores descartados y ast_free libera el árbol. Las tablas
semántica y de operandos LLVM toman referencias prestadas del AST y liberan
sus entradas. Los temporales de salida se eliminan ante fallos; el script publica
el directorio tras enlace y verificaciones. Si falla malloc, los módulos terminan
con diagnóstico; no se ensayó inyección de fallos de asignación.

Se compiló una variante con Clang y AddressSanitizer y se ejecutaron una entrada
válida, un error sintáctico y uno semántico; no se reportaron errores de acceso.
Se usó detect_leaks=0: no es una prueba de fugas. /dev/full no reprodujo un
error para el ejecutable Windows; cerrar stdout sí produjo estado 1 y el
diagnóstico previsto. No se verificaron entradas de profundidad arbitraria ni
todos los posibles fallos de E/S.

## LLVM y extremo a extremo

Los casos válidos nuevos generan IR, verifican firmas, patrón esperado, unicidad
de temporales y salida determinista; llvm-as y opt -passes=verify aceptaron cada
módulo. Los ejemplos enteros, decimales y mixto recorrieron fuente, AST,
semántica, IR, bitcode, ensamblador, objeto, ELF y HEX. Los casos inválidos no
publican firmware.

La validación conserva 18 pruebas sintácticas, 26 semánticas, 34 LLVM y 24 AVR
previas, además de 35 integrales: 137 aprobadas y 0 fallidas. Bison: 0 conflictos
shift/reduce y 0 reduce/reduce. make clean, make y make test ejecutan el conjunto.
make test-integration ejecuta por separado las suites AVR e integral; la prueba
del runtime anfitrión se compila como dependencia.

## AVR y tamaños

Se verifican -mdouble=64 y el multilib avr6/double64. Las sondas muestran
coincidencia estática de registros para las firmas print_i32 y print_f64 de los
ejemplos, no la ABI del runtime docente ni ejecución. El main provisional llama
olc_program después de configurar USART0 para 16 MHz y 115200 baudios nominales.

| Programa | Flash estática | RAM estática |
|---|---:|---:|
| enteros | 3514 bytes | 24 bytes |
| decimales | 3520 bytes | 24 bytes |
| mixto | 3532 bytes | 24 bytes |

avr-size cuenta .text, .data y .bootloader para Flash, y .data, .bss y .noinit
para RAM. No mide la pila dinámica ni el consumo del runtime docente.

## Simulación y matriz de estado

No se encontró qemu-system-avr, simavr ni avr-gdb en el entorno comprobado.
La [documentación QEMU](https://www.qemu.org/docs/master/system/target-avr.html)
describe la máquina mega2560 y salida serial. El paquete CLANG64 de MSYS2 incluye
qemu-system-avr, pero pacman mostró alrededor de 1,09 GiB instalado y numerosas
dependencias; no se consideró de bajo impacto ni se instaló. No se simuló ningún
resultado. simavr describe soporte preliminar para partes grandes y UART, pero
no se encontró instalado ni en la consulta local de pacman.

| Área | Estado | Evidencia o dependencia |
|---|---|---|
| Análisis, AST y semántica | Validado | Pruebas automáticas y límites indicados. |
| LLVM | Validado estructuralmente | llvm-as y opt; no ejecutan el programa. |
| ELF/HEX para AVR | Validado por enlace | Arquitectura, símbolos y tamaños inspeccionados. |
| ABI decimal y formato provisional | Parcialmente validado | Sondas estáticas y formato en anfitrión; falta ejecución. |
| Simulación | Pendiente | Ningún simulador compatible disponible en este entorno. |
| Salida UART en placa | Pendiente | No se realizó prueba física. |
| Runtime y evaluación oficial | Bloqueado por dependencia externa | Docente aún no proporcionó runtime, placa ni procedimiento. |

## Información pendiente y Fase 7

Solicitar al docente archivos del runtime oficial, firmas, convenciones de
llamada y opciones de double, punto de entrada, frecuencia, velocidad y formato
serial, y procedimiento de carga y monitor. Integrar ese soporte y verificar en
simulador o placa sin presentar el runtime provisional como oficial. El ensayo
personal debe ser escrito por el estudiante según el PDF.
