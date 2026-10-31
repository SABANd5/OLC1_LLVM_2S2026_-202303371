CC = gcc
FLEX = flex
BISON = bison
CPPFLAGS = -Isrc/ast -Isrc/semantic -Isrc/codegen -Ibuild
CFLAGS = -std=c11 -Wall -Wextra -Wpedantic -g
OBJECTS = build/main.o build/ast.o build/semantic.o build/codegen.o build/parser.tab.o build/lex.yy.o

.PHONY: all test test-integration clean
all: bin/compilador.exe

build bin:
	mkdir -p $@

build/parser.tab.c build/parser.tab.h &: src/parser/parser.y | build
	$(BISON) -Wall -Werror=conflicts-sr -Werror=conflicts-rr --report=state -d -o build/parser.tab.c $<

build/lex.yy.c: src/lexer/lexer.l build/parser.tab.h | build
	$(FLEX) -o $@ $<

build/main.o: src/main.c src/ast/ast.h src/semantic/semantic.h src/codegen/codegen.h build/parser.tab.h | build
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@
build/ast.o: src/ast/ast.c src/ast/ast.h | build
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@
build/semantic.o: src/semantic/semantic.c src/semantic/semantic.h src/ast/ast.h | build
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@
build/codegen.o: src/codegen/codegen.c src/codegen/codegen.h src/ast/ast.h | build
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@
build/parser.tab.o: build/parser.tab.c src/ast/ast.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@
build/lex.yy.o: build/lex.yy.c build/parser.tab.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@
bin/compilador.exe: $(OBJECTS) | bin
	$(CC) $(CFLAGS) $(OBJECTS) -o $@
build/semantic_types.exe: tests/semantic_types.c build/ast.o build/semantic.o
	$(CC) $(CPPFLAGS) $(CFLAGS) $^ -o $@
build/runtime_host.exe: tests/test_runtime_host.c runtime/avr/format.c runtime/avr/runtime.h | build
	$(CC) $(CFLAGS) -Iruntime/avr tests/test_runtime_host.c runtime/avr/format.c -o $@
test: all build/semantic_types.exe build/runtime_host.exe
	sh tests/run_tests.sh
	sh tests/test_semantic.sh
	sh tests/test_codegen.sh
	sh tests/test_avr.sh
	sh tests/test_integral.sh
	sh tests/test_led.sh
test-integration: all build/runtime_host.exe
	sh tests/test_avr.sh
	sh tests/test_integral.sh
	sh tests/test_led.sh
clean:
	rm -rf build bin
