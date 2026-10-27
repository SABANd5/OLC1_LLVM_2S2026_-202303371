# Matriz de cumplimiento

Referencia: PDF oficial, secciones 4.2–4.10, 5 y 7, páginas 4–16. «Cumplido»
indica evidencia verificable en el repositorio, no una calificación oficial.

| Requisito y referencia | Implementación / entregable | Prueba o evidencia | Estado y observaciones |
|---|---|---|---|
| Compilador C, Flex y Bison, §4.3 y 4.9, pp. 6 y 13 | src/main.c, src/lexer/lexer.l, src/parser/parser.y, Makefile | Construcción y tests/run_tests.sh | Cumplido para la implementación anfitriona. |
| Lenguaje let, print, operadores, paréntesis, literales e identificadores, §4.2, p. 5 | lexer.l y parser.y | tests/run_tests.sh, tests/test_integral.sh | Cumplido según reglas léxicas documentadas. |
| Gramática no ambigua, sin directivas de precedencia, §4.2, p. 5 | parser.y, Makefile | build/parser.output; Bison trata conflictos como error | Cumplido: 0 conflictos shift/reduce y reduce/reduce en la generación verificada. |
| AST propio para semántica y LLVM, §4.3, p. 6 | src/ast/, parser.y, semantic.c, codegen.c | tests/run_tests.sh, tests/semantic_types.c, tests/test_codegen.sh | Cumplido. |
| Entorno global y tabla de símbolos, §4.4, p. 7 | src/semantic/semantic.c | tests/test_semantic.sh | Cumplido; entradas contienen nombre, tipo, ubicación y nodo. |
| Asignación única y nombres previamente declarados, §4.2 y 4.4, pp. 5 y 7 | parser.y, semantic.c | pruebas de duplicación, referencia adelantada y autorreferencia | Cumplido; no existe sintaxis de reasignación. |
| Tipos y errores: no declarada, duplicada e incompatibles, sin conversión implícita, §4.4, p. 7 | semantic.c, ast.h | tests/test_semantic.sh, tests/semantic_types.c | Cumplido para las reglas obligatorias. |
| Operaciones i32 y double, §4.5, p. 9 | src/codegen/codegen.c | tests/test_codegen.sh, llvm-as y opt | Cumplido estructuralmente; la ejecución física queda pendiente. |
| Temporales únicos, §4.5, p. 9 | codegen.c | tests/test_codegen.sh, tests/test_integral.sh | Cumplido en módulos generados. |
| print_i32 / print_f64, §4.5, p. 9 | codegen.c; runtime/avr/ provisional | pruebas LLVM, sondas ABI y enlace | Parcial: firmas IR verificadas; salida serial con runtime docente aún no demostrada. |
| Resultado para carné mod 3 y ATmega2560, §4.6, p. 10 | scripts/build_avr.sh, runtime/avr/ | tests/test_avr.sh, tests/test_integral.sh; ELF/HEX | Parcial: backend y enlace provisional verificados; ejecución física pendiente. |
| Demostración en placa y salida en monitor serial, §4.7 y 4.9, pp. 11 y 13 | runtime/avr/ provisional | No hay ejecución real | Bloqueado por placa y soporte docente; la evaluación presencial es pendiente. |
| Compilador fuente y archivos Flex/Bison, §7, p. 16 | src/, Makefile | Archivos versionados; compilación limpia | Cumplido. |
| Archivo .ll generado para ejemplo válido, §7, p. 16 | examples/llvm/enteros.ll, decimales.ll, mixto.ll | tests/test_codegen.sh regenera, compara y verifica LLVM | Cumplido. |
| DOCUMENTACION.md con los apartados requeridos, §7, p. 16 | DOCUMENTACION.md | Revisión de apartados contra el PDF | Cumplido como documento; los resultados físicos se indican pendientes. |
| Ensayo individual en PDF de máximo dos páginas, §7, p. 16 | No existe en los archivos versionados | git ls-files '*.pdf' no muestra ensayo | Pendiente: el estudiante debe redactarlo íntegramente sin IA e incorporarlo. |
| Nombre de repositorio, §7, p. 15 | Directorio local correcto | Remoto configurado: OLC1_LLVM_2S2026_-202303371 | Pendiente: el remoto incluye un guion adicional antes del carné. |
| Commits progresivos durante el período, §7, pp. 15–16 | Historial Git | Avances 562eb1d a 9a50537 visibles en fechas 26–27 octubre | Parcial: hay avances reales separados, pero se concentran cerca de la fecha indicada; la validez es decisión del curso. |
| Revisión de privacidad y archivos generados | .gitignore, DIAGNOSTICO_ENTORNO.md | Revisión de archivos versionados y búsqueda de patrones comunes de credenciales | Parcial: no se encontraron patrones comunes en el árbol actual; una ruta de perfil personal figura en un commit anterior y no se reescribió el historial. |

El PDF advierte que un historial que no evidencie trabajo continuo puede limitar
la nota a 3/6. El usuario indicó prórroga al 29 de octubre de 2026; el PDF
entregado indica 23 de octubre. No se dispone aquí de la comunicación oficial de
la prórroga. El runtime provisional no es un requisito de implementación del
estudiante y no sustituye los archivos que proporcionará el docente.
