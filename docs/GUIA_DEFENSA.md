# Guía de estudio para la defensa

Use estas preguntas para estudiar y verificar el código. Las respuestas son
explicaciones técnicas del proyecto, no sustituyen la comprensión individual.

1. **¿Qué hace Flex?** Convierte caracteres en tokens mediante las reglas de
   src/lexer/lexer.l; también registra ubicaciones y reporta caracteres inválidos.
2. **¿Qué hace Bison?** Aplica la gramática de src/parser/parser.y y construye
   nodos AST desde las reducciones. Si encuentra sintaxis inválida, informa error.
3. **¿Por qué no hay conflictos?** La gramática separa expresión, término y
   factor. Bison se ejecuta con errores ante conflictos y su informe verificado
   no contiene shift/reduce ni reduce/reduce. No usa directivas de precedencia.
4. **¿Cómo se expresan precedencia y asociatividad?** Los términos agrupan
   multiplicación y división antes de suma y resta; la recursión izquierda hace
   que las operaciones del mismo nivel se asocien por la izquierda.
5. **¿Qué es el AST y cómo se construye?** Es una representación estructurada
   del programa. Las acciones de parser.y llaman a constructores de src/ast/;
   luego la semántica y el generador recorren los nodos.
6. **¿Cómo funciona la tabla de símbolos?** src/semantic/semantic.c mantiene
   una lista global para el análisis en orden. Guarda nombre, tipo, ubicación y
   declaración, y libera la lista al terminar.
7. **¿Cómo se infieren tipos?** Los literales determinan entero o decimal; una
   referencia obtiene el tipo declarado y una binaria exige tipos iguales y
   devuelve ese tipo. El resultado se anota en el AST.
8. **¿Cómo se detecta un nombre no declarado?** Se busca en la tabla en el
   momento del uso. La inicialización se analiza antes de registrar el nombre,
   por lo que la referencia adelantada o propia falla.
9. **¿Por qué no hay conversiones implícitas?** El enunciado las prohíbe. Una
   operación entre entero y decimal es error semántico antes de emitir IR.
10. **¿Qué es LLVM IR?** Es una representación intermedia tipada; el generador
    de src/codegen/codegen.c emite texto que las herramientas LLVM verifican y
    transforman para una arquitectura.
11. **¿Qué es SSA?** Una representación donde cada nombre de valor se define una
    sola vez. En este proyecto cada operación binaria recibe un temporal %tN
    único; los literales pueden aparecer como operandos directos.
12. **¿Cómo se representan variables inmutables?** El generador asocia cada
    identificador al operando de su inicialización; no necesita alloca, load ni
    store para la semántica de asignación única de este lenguaje.
13. **¿En qué difieren add y fadd?** add opera sobre i32; fadd sobre double.
    La selección depende del tipo validado y anotado en el AST.
14. **¿En qué difieren sdiv y fdiv?** sdiv divide enteros con signo y fdiv
    divide valores de punto flotante. Una división entera por cero, o INT32_MIN
    entre -1, tiene comportamiento indefinido en LLVM y no se valida en esta fase.
15. **¿Qué hace llvm-as?** Convierte el IR textual en bitcode y rechaza módulos
    inválidos. opt -passes=verify comprueba estructura; ninguna de esas
    operaciones demuestra ejecución del programa.
16. **¿Qué hace llc?** Usa un backend LLVM para transformar bitcode o IR en
    código para un destino, aquí ensamblador AVR seleccionado con atmega2560.
17. **¿Qué hace AVR-GCC?** Ensambla el código producido, compila el runtime C
    y enlaza los objetos y bibliotecas en un ELF para AVR.
18. **¿Cómo se genera el HEX?** avr-objcopy transforma el ELF enlazado a Intel
    HEX. Ese archivo no prueba que se haya cargado ni ejecutado en placa.
19. **¿Qué es una ABI?** Es el conjunto de convenciones que permite interoperar
    entre componentes: representación de tipos, registros, pila, llamadas y
    retornos son ejemplos relevantes.
20. **¿Por qué -mdouble=64?** El IR usa double de 64 bits; el AVR-GCC instalado
    usa 32 por defecto y ofrece el multilib avr6/double64. Las sondas muestran
    coincidencia de registros para dos firmas, no para todo runtime posible.
21. **¿Cómo funciona el runtime provisional?** runtime/avr/main.c inicializa
    USART0 y llama olc_program; format.c implementa print_i32 y print_f64 y
    uart.c transmite caracteres. Es reemplazable y no es el runtime docente.
22. **¿Qué falta verificar?** La ABI y entrada del runtime docente, el enlace
    con ese soporte, la carga, la salida serial y el funcionamiento en placa o
    simulador. Los tamaños estáticos no incluyen el consumo dinámico de pila.
23. **¿Cómo llega led 13 on al pin?** Flex y Bison reconocen la instrucción;
    semántica valida el pin y el generador emite una llamada a olc_led13_on.
    runtime/avr/led.c configura DDRB7 y PORTB7, correspondiente a D13/PB7 en
    Mega 2560. La funcionalidad física aún requiere prueba y la extensión no
    aparece en el PDF original.

Para comandos de práctica y evidencia consulte [GUIA_DEMOSTRACION.md](GUIA_DEMOSTRACION.md).
