CC = gcc
FLEX = flex
BISON = bison
CPPFLAGS = -Isrc/ast -Ibuild
CFLAGS = -std=c11 -Wall -Wextra -Wpedantic -g
OBJECTS = build/main.o build/ast.o build/parser.tab.o build/lex.yy.o

.PHONY: all test clean
all: bin/compilador.exe

build bin:
	mkdir -p $@

build/parser.tab.c build/parser.tab.h &: src/parser/parser.y | build
	$(BISON) -Wall -Werror=conflicts-sr -Werror=conflicts-rr --report=state -d -o build/parser.tab.c $<

build/lex.yy.c: src/lexer/lexer.l build/parser.tab.h | build
	$(FLEX) -o $@ $<

build/main.o: src/main.c src/ast/ast.h build/parser.tab.h | build
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@
build/ast.o: src/ast/ast.c src/ast/ast.h | build
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@
build/parser.tab.o: build/parser.tab.c src/ast/ast.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@
build/lex.yy.o: build/lex.yy.c build/parser.tab.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@
bin/compilador.exe: $(OBJECTS) | bin
	$(CC) $(CFLAGS) $(OBJECTS) -o $@
test: all
	sh tests/run_tests.sh
clean:
	rm -rf build bin
