# Información pendiente para evaluación presencial

Solicitar al docente:

- Archivos y versiones del runtime oficial y sus dependencias.
- Firmas exactas de print_i32 y print_f64 y formato esperado de salida.
- ABI de parámetros y retorno, tamaño de double y opciones de compilación;
  confirmar compatibilidad con LLVM y con AVR-GCC -mdouble=64.
- Nombre y firma del punto de entrada, y archivos de arranque o integración.
- Frecuencia real del microcontrolador y configuración serial: baudios,
  paridad, bits y fin de línea.
- Procedimiento y herramienta de carga, identificación del puerto y herramienta
  para abrir el monitor serial.
- Disponibilidad de Arduino Mega 2560 o de un simulador y pasos de prueba.
- Confirmación oficial de la fecha prorrogada y del nombre exacto del repositorio.

Sin esos recursos se pueden generar y verificar LLVM IR, generar ensamblador
AVR, compilar objetos, enlazar ELF y crear HEX con el runtime provisional;
también se pueden inspeccionar símbolos y tamaños. Esas actividades no prueban
la ABI del runtime docente, la carga física ni la salida serial de la placa.
