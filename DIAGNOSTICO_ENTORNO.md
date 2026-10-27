# Diagnóstico de entorno — Fase 1

Fecha: 26 de octubre de 2026. Carné 202303371: `202303371 mod 3 = 0`, corresponde Arduino Mega 2560, AVR ATmega2560.

## Referencias

- `%USERPROFILE%\Downloads\Tarea_OLC1_LLVM_2S2026.pdf`, 17 páginas: enunciado oficial. Indica entrega el **23 de octubre de 2026**, en páginas 1 y 16; el usuario indicó 29 de octubre. Confirmar con el curso si existe una prórroga; no se dispone de evidencia de ella.
- `%USERPROFILE%\Downloads\Comandos.md`: guía del auxiliar para UCRT64, CLANG64 y flujo AVR; sus rutas y puerto son de otra computadora.
- `%USERPROFILE%\Downloads\Minibot.zip`: inspeccionado sin modificar ni copiar sus fuentes. Contiene `src/{lexer,parser,ast,semantic,codegen}`, ejemplos, pruebas, runtimes, targets y artefactos generados.

## Requisitos oficiales principales

- Compilador en C; Flex, Bison, AST propio y tabla de símbolos de ámbito global. El análisis semántico antecede a cualquier emisión LLVM.
- Únicamente `let identificador = expresion;`, `print expresion;`, identificadores declarados, enteros, decimales, paréntesis y operadores `+ - * /`.
- Gramática no ambigua que exprese precedencia y asociatividad por producciones, sin `%left`, `%right`, `%nonassoc`, `%precedence` ni `%prec`; Bison sin conflictos shift/reduce ni reduce/reduce.
- Detectar uso no declarado, declaración duplicada y operandos de tipos incompatibles; no convertir implícitamente enteros y decimales. Variables de asignación única.
- Enteros `i32`: `add`, `sub`, `mul`, `sdiv`; decimales `double`: `fadd`, `fsub`, `fmul`, `fdiv`. Cada operación produce un temporal único. `print` usa `print_i32(i32)` o `print_f64(double)`.
- Generar `.ll` válido y código para AVR. El docente proporcionará runtime, soporte, carga y placa para comprobar la salida serial en evaluación presencial; no se exige comprar placa ni programar drivers.
- Excluidos: condicionales, ciclos, funciones de usuario, arreglos, cadenas, estructuras, reasignación, ámbitos múltiples, optimizaciones, conversiones implícitas y ensamblador manual.
- Entrega: repositorio GitHub `OLC1_LLVM_2S2026_202303371`, código, `.ll` de ejemplo, `DOCUMENTACION.md` con los apartados de la página 16, y ensayo personal PDF de máximo dos páginas. El PDF prohíbe IA generativa para redactar, reescribir, resumir o parafrasear el ensayo. Exige historial progresivo real; si no lo evidencia, limita la nota a 3/6. Esta fase no crea commits ni publica el repositorio.

## Análisis de MiniBot

Son referencias de arquitectura sus fases independientes, organización C/Flex/Bison, AST, expresiones con niveles de precedencia, diagnósticos, emisión textual de IR, verificación y flujo llc/AVR. Su lenguaje `start/stop`, `move`, `turn`, `led`, `wait`, `beep`, `message`, `repeat` y simulación no son requisitos de esta tarea. Sus comprobaciones semánticas particulares no sustituyen tabla de símbolos y reglas del enunciado. Sus runtimes exponen `mb_*`; no se ha demostrado que implementen `print_i32` ni `print_f64`, por lo que no se debe asumir compatibilidad con el runtime docente.

## Sistema y diagnóstico inicial

Windows 11 según contexto proporcionado; consulta CIM denegada en el aislamiento. MSYS2 existente en `C:\msys64`. Git `C:\Program Files\Git\cmd\git.exe` 2.53.0.windows.2. LLVM independiente `C:\LLVM\bin` 23.1.0: `clang`, `llvm-as`, `llvm-dis`, `llc`; su lista de destinos no incluye AVR. Inicialmente GCC UCRT64 15.2.0 y paquetes MSYS Make 4.4.1, Flex 2.6.4 y Bison 3.8.2; los tres últimos estaban fuera del PATH de PowerShell, pero dentro de MSYS2. `C:\msys64\usr\bin\bash.exe` no inició dentro del sandbox (`NtCreateDirectoryObject ... 0xC0000022`); se ejecutó fuera de este para diagnóstico y preparación.

## Preparación y comandos

Se consultaron paquetes con `pacman -Q`, `pacman -Ss` y `pacman -Si`. La base anterior ofrecía LLVM y AVR GCC/binutils/avrdude en CLANG64, pero no `mingw-w64-clang-x86_64-avr-libc`; sí mostraba variantes UCRT64 y MINGW64. Se ejecutó `pacman -Syu --noconfirm`, con reinicio de la terminal MSYS2 tras la actualización del núcleo, seguido de otra ejecución para la actualización completa. No se instaló WSL.

## Prueba reproducible y límites

El IR mínimo está en `tests/avr_minimo.ll`: una suma `i16`, elegida para verificar el backend y no para probar el compilador ni las funciones de impresión. Los archivos generados se colocan en `build/`, ignorado por Git.

```sh
llvm-as tests/avr_minimo.ll -o build/avr_minimo.bc
llvm-dis build/avr_minimo.bc -o build/avr_recuperado.ll
llc -mtriple=avr -mcpu=atmega2560 -filetype=asm build/avr_minimo.bc -o build/avr_minimo.S
avr-gcc -mmcu=atmega2560 -c build/avr_minimo.S -o build/avr_minimo.o
```

Con `C:\LLVM\bin` 23.1.0, `llvm-as` y `llvm-dis` terminaron correctamente; `llc` falló: `unable to get target for 'avr'`, código 1. Esta instalación independiente no sirve para el backend requerido.

Un objeto AVR solo confirma ensamblado; el firmware requiere enlace con un punto de entrada y runtime compatibles, y ejecución física requiere cargarlo y observar la placa. No se han verificado ni firmware ni ejecución física. La prueba mínima no verifica ABI, `double`, biblioteca de punto flotante ni funciones de impresión; deben verificarse posteriormente con el soporte docente.

### Resultado final de instalación y verificación

`pacman -Ss` después de sincronizar confirmó `mingw-w64-clang-x86_64-clang`, `-llvm`, `-avr-gcc`, `-avr-libc`, `-avr-binutils` y `-avrdude` (cada nombre completo lleva el prefijo `mingw-w64-clang-x86_64-`). Se instalaron mediante `pacman -S --needed --noconfirm` con esos nombres. También se completó la actualización de los paquetes ya existentes. La primera transacción completa se interrumpió antes de modificar paquetes, al permanecer varios minutos en `checking available disk space`; el proceso quedó huérfano y se detuvo. Se comprobó que no quedaba ningún pacman activo, se eliminó el `db.lck` residual con `rm` desde MSYS2 y se reanudó con `pacman --config <configuración temporal> -Su --noconfirm`. La configuración temporal en `build/pacman.conf` deshabilita únicamente `CheckSpace`; se verificaron previamente más de 38 GB libres. El archivo permanente `C:\msys64\etc\pacman.conf` no se modificó. Tanto la actualización como la instalación terminaron con código 0.

| Herramienta | Ubicación real | Versión comprobada |
|---|---|---|
| Git | `C:\Program Files\Git\cmd\git.exe` | 2.53.0.windows.2 |
| MSYS2 bash / runtime | `C:\msys64\usr\bin\bash.exe` | runtime actualizado 3.6.11-4 |
| GCC UCRT64 | `C:\msys64\ucrt64\bin\gcc.exe` | 16.2.0, paquete 16.2.0-6 |
| Make | `C:\msys64\usr\bin\make.exe` | 4.4.1, paquete 4.4.1-3 |
| Flex | `C:\msys64\usr\bin\flex.exe` | 2.6.4, paquete 2.6.4-4 |
| Bison | `C:\msys64\usr\bin\bison.exe` | 3.8.2, paquete 3.8.2-5 |
| Clang | `C:\msys64\clang64\bin\clang.exe` | 23.1.4 |
| LLVM, llvm-as, llvm-dis, llc | `C:\msys64\clang64\bin\` | 23.1.4 |
| avr-gcc | `C:\msys64\clang64\bin\avr-gcc.exe` | 16.2.0 |
| avr-objcopy | `C:\msys64\clang64\bin\avr-objcopy.exe` | GNU binutils 2.47.20260726 |
| avrdude | `C:\msys64\clang64\bin\avrdude.exe` | 8.3-20261018 |
| avr-libc | paquete `mingw-w64-clang-x86_64-avr-libc` | 2.3.2-1 |

En una sesión UCRT64, `gcc -std=c11 -Wall -Wextra build/entorno.c -o build/entorno.exe` y `./build/entorno.exe` compilaron y ejecutaron correctamente un programa C mínimo (`UCRT64 OK`). Make, Flex y Bison se consultaron por ruta y versión, sin construir aún un lexer ni parser del proyecto.

En CLANG64, `llc --version` registra `avr`; se ejecutaron exitosamente los cuatro comandos de la prueba anterior. `avr-objdump -f build/avr_minimo.o` informó `file format elf32-avr` y `architecture: avr:6`. Esto comprueba IR válido, conversión a bitcode y recuperación, selección `atmega2560`, ensamblador AVR y objeto ensamblado. No se enlazó firmware ni se ejecutó en placa.

El repositorio local se inicializó con `git init`, sin commits ni remoto. La estructura contiene `src/{lexer,parser,ast,semantic,codegen}`, `examples`, `tests`, `docs` y `build` ignorado, además de `.gitignore` y este diagnóstico. `tests/avr_minimo.ll` es una prueba manual del backend, no un resultado del compilador. Los archivos generados no se incluyen en Git.

Pendientes para fases posteriores: desarrollar el compilador y sus pruebas, generar un `.ll` de un programa del lenguaje, documentar la solución final, confirmar plazo, crear historial progresivo auténtico y publicar según instrucciones futuras. Comprobar específicamente la ABI de `double`, las llamadas y el runtime docente antes de afirmar que la impresión funciona en AVR.
