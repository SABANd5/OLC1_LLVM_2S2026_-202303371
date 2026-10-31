# Fase 9: LED integrado en Arduino Mega 2560

## Objetivo y alcance

Se agregó la instrucción exacta `led 13 on;` para preparar una demostración
del LED integrado. El estudiante informó que el auxiliar cambió la demostración
al LED. El PDF original limita el lenguaje a expresiones y print; no contiene
esta extensión ni se dispone aquí de la comunicación oficial del cambio. Se
mantienen las funciones existentes. Las palabras `led` y `on` pasan a ser
reservadas y ya no pueden usarse como identificadores.

El lexer reconoce ambas palabras; Bison construye un nodo AST_LED con el texto
del pin y el estado on. La semántica exige el texto exacto `13` y estado on;
otros pines, incluido `013`, se rechazan. `off` no es una instrucción y se
rechaza por sintaxis. Solo después de validar, el generador produce:

~~~llvm
declare void @olc_led13_on()

define void @olc_program() {
entry:
  call void @olc_led13_on()
  ret void
}
~~~

El módulo completo también declara las funciones de impresión existentes.
`runtime/avr/led.c` implementa la función sin argumentos: establece el bit
DDB7 de DDRB como salida y el bit PORTB7 de PORTB en uno. El punto de entrada
existente inicializa UART y llama a olc_program; no enciende directamente el
LED. Tras retornar el programa, main permanece en su bucle, sin apagar el pin.

El pin digital D13 de la Mega 2560 corresponde a PB7 y al LED integrado, según
el [pinout oficial de Arduino Mega 2560 Rev3](https://docs.arduino.cc/resources/datasheets/A000067-datasheet.pdf)
y el [mapeo de la variante Mega de ArduinoCore-avr](https://github.com/arduino/ArduinoCore-avr/blob/master/variants/mega/pins_arduino.h).
MiniBot se consultó como referencia: usa su propia ABI `mb_led_set(i32, i32)`,
un nodo LED y un runtime AVR con PB7 para D13. Esta implementación usa su
propia función `olc_led13_on` y no copia sus binarios ni su runtime.

## Archivos y construcción

Los cambios comprenden lexer, parser, AST, semántica, generador LLVM,
`runtime/avr/led.c`, `runtime/avr/runtime.h`, `scripts/build_avr.sh`,
`Makefile`, el ejemplo `examples/hardware/led_mega.olc`, pruebas y
documentación. Un runtime alternativo seleccionado con AVR_RUNTIME_DIR debe
proporcionar también led.c con la función requerida.

En MSYS2 UCRT64, desde la raíz:

~~~sh
make
make test
./bin/compilador.exe examples/hardware/led_mega.olc
~~~

En MSYS2 CLANG64, desde la raíz, seleccione un directorio de salida que no
exista:

~~~sh
sh scripts/build_avr.sh examples/hardware/led_mega.olc build/avr/led_demo
cat build/avr/led_demo/program.ll
llvm-dis build/avr/led_demo/program.bc -o build/avr/led_demo/recuperado.ll
opt -passes=verify -disable-output build/avr/led_demo/program.bc
avr-objdump -f build/avr/led_demo/firmware.elf
avr-nm --undefined-only build/avr/led_demo/firmware.elf
avr-nm build/avr/led_demo/firmware.elf | grep -E 'olc_program|olc_led13_on'
avr-objdump -d build/avr/led_demo/firmware.elf | grep -A 4 '<olc_led13_on>:'
~~~

El script genera program.ll, program.bc, program.S, program.o, firmware.elf y
firmware.hex; comprueba símbolos no resueltos y usa `-mmcu=atmega2560` y
`-mdouble=64` para conservar compatibilidad con el runtime provisional.
En la inspección realizada, el ELF es `elf32-avr`, arquitectura `avr:6`,
sin símbolos indefinidos. El desensamblado de la función muestra escrituras del
bit 7 en las direcciones de E/S de DDRB y PORTB. Esto es evidencia estática,
no una ejecución del hardware.

## Procedimiento de carga, solo tras confirmación

No se ha cargado ningún firmware durante esta fase. Conecte e identifique la
Mega 2560 y su puerto mediante el Administrador de dispositivos de Windows o,
en CLANG64, consulte los puertos candidatos:

~~~sh
avrdude -P '?s'
~~~

Después de confirmar la placa, el puerto y la autorización del estudiante,
configure el puerto realmente observado y ejecute el siguiente comando. No
copie el marcador literalmente:

~~~sh
PUERTO='COM<puerto-identificado>'
avrdude -p m2560 -c wiring -P "$PUERTO" -b 115200 -D +  -U flash:w:build/avr/led_demo/firmware.hex:i
~~~

Observe el LED integrado L/13 después de completar la carga. Un resultado real
debe registrarse solo después de observarlo. Una placa distinta, otro bootloader
o un puerto incorrecto pueden requerir parámetros distintos.

## Pruebas y límites

Se ejecutaron las 137 pruebas anteriores y 17 específicas de LED: 154 aprobadas,
0 fallidas. Bison informó 0 conflictos shift/reduce y reduce/reduce. Las pruebas
LED cubren palabras reservadas, AST, pin válido e inválido, sintaxis inválida,
coexistencia con let/print, LLVM, enlace, HEX, símbolos y desensamblado.
No se realizaron carga, simulación ni prueba física. El runtime y el enlace son
provisionales; si el docente usa otro entorno debe disponer de una
implementación compatible de olc_led13_on, además del punto de entrada.
