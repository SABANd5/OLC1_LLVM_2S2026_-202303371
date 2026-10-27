# Fase 5: integración AVR y runtime provisional

## Alcance y referencias

El PDF oficial exige print_i32(i32) y print_f64(double) y señala que el
docente proporcionará runtime y placa. Esta implementación es un runtime
**provisional**, separado y reemplazable. MiniBot usa la ABI mb_*, no nuestras
funciones; no se copiaron sus fuentes.

Herramientas: LLVM/llc 23.1.4 de MSYS2 CLANG64, AVR-GCC 16.2.0, AVR binutils
2.47 y avr-libc 2.3.2. El compilador anfitrión se construye con GCC UCRT64.
No se ejecutó avrdude.

## ABI: investigación y límites

Por defecto AVR-GCC define __SIZEOF_DOUBLE__=4 y __DBL_MANT_DIG__=24.
La opción -mmcu=atmega2560 -mdouble=64 funciona en esta instalación: las
macros pasan a 8 y 53, respectivamente, y -print-multi-directory selecciona
avr6/double64. Existen libc.a y libgcc.a para ese multilib; se encontraron
__adddf3, __muldf3 y __fixunsdfsi en libgcc. Se usa -mdouble=64 tanto al
compilar el runtime como al enlazar. La documentación de [opciones AVR de
GCC](https://gcc.gnu.org/onlinedocs/gcc/AVR-Options.html) explica que la
disponibilidad y los multilib dependen de la configuración.

La sonda tests/abi_probe.c contiene receptores C y un llamador GCC.
tests/abi_probe.olc produce llamadores LLVM con el compilador del proyecto.
Se inspeccionaron los ensambladores generados con -O1 para GCC y con llc
para LLVM, y se enlazaron los objetos. Para los casos concretos:

- Para print_f64(2.5), LLVM coloca 0x4004000000000000 en r18–r25, byte menos
  significativo primero; el receptor GCC almacena esos registros en ese orden.
  El llamador GCC usa los mismos registros y bytes.
- Para print_i32(19088743) (0x01234567), LLVM y GCC colocan los bytes
  67 45 23 01 hexadecimal en r22–r25; el receptor GCC los almacena en ese orden.
- Las funciones tienen un argumento y retorno void: en estas sondas el argumento
  viaja en registros, sin argumentos en pila ni valor de retorno que comparar.
  Los ensambladores usan call y ret. Los cuerpos observados no reservan pila
  adicional; la llamada usa la pila normal para la dirección de retorno.

Esta es evidencia estática para esas firmas y versiones, no una demostración de
todas las convenciones, ejecución en hardware ni compatibilidad con el runtime
docente. La sonda enlaza, pero no se ejecutó en simulador ni placa. LLVM puede
plegar las expresiones constantes; no se ha probado en hardware la aritmética
double ni la interoperabilidad general de sus helpers.

## Runtime y UART

- runtime/avr/format.c ofrece print_i32 y print_f64. El entero se convierte sin
  negar INT32_MIN y se termina con CRLF.
- El decimal usa tres cifras fraccionarias, redondeo mediante escalado y suma
  de 0.5 sobre el valor binario, y CRLF. Es un formato de prueba, no una
  especificación del curso. Conserva signo negativo, incluso cero negativo;
  NaN se imprime como nan. Infinitos y magnitudes desde 1 000 000 se informan
  como fuera_de_rango, con signo si es negativo. Los valores cercanos a un
  punto medio dependen del redondeo binario.
- uart.c configura transmisión USART0 con U2X0, 8 bits, sin paridad y un bit
  de parada. Se asume F_CPU de 16 MHz y velocidad nominal de 115200 baudios;
  con UBRR0=16 la velocidad calculada es aproximadamente 117647 baudios,
  error +2,12 %. TX0 corresponde al pin 1 de la Mega. No se verificaron
  físicamente la frecuencia, la señal, el monitor ni la tolerancia del receptor.
- main.c inicializa UART, llama olc_program() y queda en un bucle. El arranque
  y la tabla de vectores los aporta AVR-GCC/avr-libc.

Las pruebas de formato se ejecutaron en el anfitrión, incluyendo cero,
INT32_MAX, INT32_MIN, decimal positivo, cero negativo, redondeo, NaN y límite.
No demuestran el comportamiento de esas conversiones en AVR.

## Construcción y pruebas

Desde la raíz, con MSYS2 y herramientas CLANG64 instaladas:

    make clean
    make
    make test
    sh scripts/build_avr.sh examples/enteros.olc build/avr/enteros
    sh scripts/build_avr.sh examples/decimales.olc build/avr/decimales
    sh scripts/build_avr.sh examples/mixto.olc build/avr/mixto

Cada directorio de salida debe ser nuevo; no se sobrescribe uno anterior.
El script usa /clang64/bin de MSYS2 por defecto; LLVM_BIN permite cambiarlo.
En un directorio temporal hermano ejecuta:

    compilador → program.ll → llvm-as → program.bc → opt -passes=verify
    → llc -mtriple=avr -mcpu=atmega2560 → program.S
    → avr-gcc -mmcu=atmega2560 -mdouble=64 → program.o
    → enlace con format.o, uart.o, main.o y multilib → firmware.elf
    → avr-objcopy -O ihex -R .eeprom → firmware.hex

El script produce undefined.txt, architecture.txt y size.txt con avr-nm,
avr-objdump y avr-size. Rechaza símbolos sin resolver y solo publica el
directorio al completar el flujo; ante error intenta limpiar el temporal.
Los artefactos quedan en build/, ignorado por Git. El enlace puede advertir que
_exit.o carece de .note.GNU-stack; la advertencia procede de la biblioteca
instalada y no se interpretó como ejecución verificada.

La suite conserva 18 pruebas sintácticas, 26 semánticas y 34 de LLVM/AVR.
La integración añade 24 comprobaciones, incluidas compilación del runtime,
multilib, símbolos libgcc, sondas ABI, enlace entero/decimal/mixto, ELF/HEX,
arquitectura, tamaño, reproducibilidad, errores semánticos y fallo de enlace
simulado. El modo host no es prueba de placa. Bison mantiene cero conflictos.

## Pendiente para la siguiente fase

Se requiere el runtime y convención de entrada reales del docente para comparar
firma, opciones de ABI y bibliotecas. Se debe validar impresión y UART en
simulador o Mega física, medir comportamiento y memoria real, y confirmar el
procedimiento de carga y monitor. No se dispone de prueba física y no debe
afirmarse salida serial real ni compatibilidad definitiva con el runtime oficial.
