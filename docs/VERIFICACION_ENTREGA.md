# Verificación de entrega

Fecha de verificación: **27 de octubre de 2026**, hora local de Guatemala.
Rama revisada: **main**. Commit base verificado antes de los cambios de esta
revisión: **8c93fe0**. El commit que contiene este documento se identifica con
el historial de Git, sin incorporar su propio hash al contenido.

Repositorio: **OLC1_LLVM_2S2026_202303371**.
El estudiante confirmó que lo renombró. La URL local de origin se actualizó a
https://github.com/SABANd5/OLC1_LLVM_2S2026_202303371.git; git ls-remote y
git fetch terminaron correctamente y, antes de los cambios de esta revisión,
main y origin/main coincidían en 8c93fe0, sin commits adelantados ni atrasados.

## Resultado técnico

- Compilación limpia en MSYS2 UCRT64: make clean y make terminaron correctamente.
- make test: 18 pruebas sintácticas, 26 semánticas, 34 LLVM, 24 AVR y 35
  integrales; **137 aprobadas, 0 fallidas**.
- Bison: 0 conflictos shift/reduce y 0 reduce/reduce; se ejecuta con opciones
  que tratan ambos tipos de conflicto como error.
- Los tres ejemplos enteros, decimales y mixto se regeneraron con el compilador,
  coincidieron con examples/llvm/ y pasaron llvm-as, llvm-dis y
  opt -passes=verify. Sus fuentes y módulos quedan versionados.
- Se generaron objetos, ELF y HEX en directorios nuevos de build/avr/enteros,
  build/avr/decimales y build/avr/mixto. Objetos y ELF informaron avr:6; los
  ELF no tenían símbolos indefinidos. Los tres HEX no estaban vacíos.
- AVR-GCC con -mdouble=64 informó double de 8 bytes, mantisa de 53 bits y
  multilib avr6/double64. La compatibilidad con el runtime docente no está
  demostrada. El enlace emitió la advertencia conocida de _exit.o sin
  .note.GNU-stack; los enlaces terminaron correctamente.

| Ejemplo | Flash estática | RAM estática |
|---|---:|---:|
| enteros | 3514 bytes | 24 bytes |
| decimales | 3520 bytes | 24 bytes |
| mixto | 3532 bytes | 24 bytes |

Los tamaños no incluyen el consumo dinámico de pila. Los artefactos de build/
son generados y no se incluyen en Git. No se ha ejecutado el firmware en
simulador ni en una placa; el runtime UART es provisional.

## Auditoría de entregables del PDF

| Requisito | Estado | Evidencia |
|---|---|---|
| Código C, Flex, Bison, AST, símbolos, semántica y generación LLVM | Cumplido | src/, Makefile y pruebas; detalle en MATRIZ_CUMPLIMIENTO.md. |
| Gramática no ambigua y sin directivas de precedencia | Cumplido | src/parser/parser.y y build/parser.output sin conflictos. |
| Ejemplo LLVM IR válido generado por el compilador | Cumplido | examples/llvm/ y regeneración/verificación descrita arriba. |
| DOCUMENTACION.md | Cumplido | Contiene los apartados de la página 16: descripción, compilación, estructura, Flex/Bison, gramática, AST, semántica, LLVM, arquitectura, proceso y ejemplo. |
| README y guías de demostración y defensa | Cumplido | Archivos presentes; el estudiante confirmó haber practicado. |
| Nombre obligatorio del repositorio | Cumplido | URL corregida y conexión Git comprobada. |
| Historial de desarrollo continuo | Parcial | Hay commits reales separados, pero concentrados en fechas próximas a la entrega; el curso decide si satisfacen el requisito. |
| Ensayo individual PDF, máximo dos páginas | Pendiente | El estudiante confirma que aún falta; debe escribirlo íntegramente e incorporarlo sin IA generativa. No hay PDF versionado en esta revisión. |
| Runtime docente, placa y salida serial presencial | Bloqueado por soporte docente | Las firmas IR y el enlace provisional están comprobados; faltan el runtime oficial y la prueba en placa. |
| Entrega formal | Pendiente | No se ha efectuado la entrega por este asistente. |

## Privacidad y revisión de documentación

Los enlaces locales de README.md, DOCUMENTACION.md y los documentos de docs/
fueron comprobados sin enlaces inexistentes. Las instrucciones reproducibles
no contienen rutas absolutas del perfil del estudiante. Se buscaron patrones
comunes de credenciales y extensiones de binarios o temporales en el árbol
actual sin coincidencias; esta revisión no garantiza ausencia de todos los
secretos. build/ y bin/ están ignorados por Git.

Una ruta del perfil personal aparece en commits anteriores de
DIAGNOSTICO_ENTORNO.md; la versión actual usa %USERPROFILE%. No se reescribió
el historial, por lo que la información histórica sigue accesible en el remoto.

## Pendientes administrativos y checklist personal

- [x] El estudiante confirmó el cambio al nombre de repositorio requerido.
- [x] El estudiante confirmó haber practicado demostración y defensa.
- [x] El estudiante confirmó la prórroga al 29 de octubre de 2026. El PDF
  original indica 23 de octubre; no se ha revisado la comunicación oficial de
  la prórroga en esta sesión.
- [ ] El estudiante redacta personalmente el ensayo individual, máximo dos
  páginas en PDF, sin IA generativa, y lo incorpora al repositorio.
- [ ] Consultar al docente por el runtime oficial, ABI de double, punto de
  entrada, placa, configuración serial y procedimiento de carga; ver
  PENDIENTES_DOCENTE.md.
- [ ] Comprobar la entrega final según el procedimiento del curso.

La concentración del historial cerca de la fecha indicada puede afectar el
requisito de trabajo continuo; la decisión corresponde al curso. En LLVM,
sdiv por cero y INT32_MIN / -1 tienen comportamiento indefinido, aunque el
verificador acepte el módulo. No se debe presentar una ejecución sin evidencia.
