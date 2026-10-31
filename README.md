# Compilador OLC1 LLVM — 202303371

Compilador educativo en C11 que analiza un lenguaje de expresiones, construye
un AST, valida símbolos y tipos y genera LLVM IR. La arquitectura asignada es
Arduino Mega 2560 (AVR/ATmega2560). El compilador corre en Windows; el firmware
AVR se construye por separado con el runtime **provisional** del repositorio.

El lenguaje permite declaraciones únicas, impresión, literales enteros y
decimales, variables declaradas, paréntesis y los operadores +, -, * y /:

~~~text
let a = 10;
let b = a + 2;
print b;
led 13 on;
~~~

La extensión LED acepta únicamente el pin 13 y el estado on. Se implementó a
petición del estudiante, quien informó un cambio de demostración del auxiliar;
el PDF original no la incluye. Las palabras led y on quedan reservadas.
No existen conversiones implícitas entre entero y decimal. La documentación
de la gramática y las limitaciones está en [DOCUMENTACION.md](DOCUMENTACION.md).

## Requisitos y ejecución

En Windows 11 se validó MSYS2 UCRT64 con GCC C11, GNU Make, Flex y Bison, y
MSYS2 CLANG64 con LLVM (llvm-as, llvm-dis, opt, llc), AVR-GCC, AVR-libc y
AVR-binutils. Las pruebas usan herramientas de línea de comandos de MSYS2.
Desde una terminal UCRT64, en la raíz del repositorio:

~~~sh
make clean
make
./bin/compilador.exe examples/mixto.olc
./bin/compilador.exe --parse-only examples/mixto.olc
./bin/compilador.exe --emit-llvm examples/mixto.olc -o build/mixto.ll
make test
~~~

El primer comando de ejecución valida semántica y muestra el AST;
--parse-only comprueba solo sintaxis. --emit-llvm genera IR tras la validación.
La suite usa por defecto /clang64/bin para LLVM y AVR; puede ajustarse con
LLVM_BIN. Desde una terminal CLANG64, se puede verificar el IR:

~~~sh
llvm-as build/mixto.ll -o build/mixto.bc
llvm-dis build/mixto.bc -o build/mixto_recuperado.ll
opt -passes=verify -disable-output build/mixto.bc
~~~

## Firmware provisional

Con el compilador construido, desde la raíz y con herramientas CLANG64:

~~~sh
sh scripts/build_avr.sh examples/mixto.olc build/avr/demo
avr-nm --undefined-only build/avr/demo/firmware.elf
avr-objdump -f build/avr/demo/firmware.elf
avr-size -C --mcu=atmega2560 build/avr/demo/firmware.elf
~~~

Para el LED use un directorio nuevo:

~~~sh
sh scripts/build_avr.sh examples/hardware/led_mega.olc build/avr/led
~~~

El directorio de salida debe ser nuevo. El script emite ELF y HEX, usa
-mdouble=64 y no carga una placa. El runtime oficial, la ABI definitiva, el
procedimiento de carga y la salida serial dependen del docente. No se ha
realizado ejecución física ni simulación.
El procedimiento de carga, que requiere identificar placa y puerto y obtener
confirmación previa, está en [Fase 9](docs/FASE_9_LED_ARDUINO.md).

Consulte [guía de demostración](docs/GUIA_DEMOSTRACION.md),
[guía de estudio](docs/GUIA_DEFENSA.md), [matriz de cumplimiento](docs/MATRIZ_CUMPLIMIENTO.md)
y [pendientes del docente](docs/PENDIENTES_DOCENTE.md).
