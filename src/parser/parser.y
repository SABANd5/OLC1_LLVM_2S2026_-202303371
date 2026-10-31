%code requires {
#include "ast.h"
}
%{
#include <stdio.h>
#include <stdlib.h>
#include "ast.h"
int yylex(void);
void yyerror(const char *message);
extern int lexical_error;
extern const char *source_filename;
AstNode *ast_root = NULL;
#define LOC(l) ((SourceLocation){(l).first_line, (l).first_column, (l).last_line, (l).last_column})
%}

%locations
%define parse.error detailed
%define parse.lac full
%union { char *text; AstNode *node; }
%token LET PRINT LED ON INVALID
%token <text> ID ENTERO DECIMAL
%type <node> programa instrucciones instruccion expresion termino factor
%destructor { free($$); } <text>
%destructor { ast_free($$); } <node>
%start programa
%%
programa: instrucciones { ast_root = ast_program($1, LOC(@$)); $$ = NULL; } ;
instrucciones: instrucciones instruccion { $$ = ast_append($1, $2); }
             | instruccion { $$ = $1; } ;
instruccion: LET ID '=' expresion ';' { $$ = ast_let($2, $4, LOC(@$)); $$->as.declaration.name_location = LOC(@2); }
           | PRINT expresion ';' { $$ = ast_print_statement($2, LOC(@$)); }
           | LED ENTERO ON ';' { $$ = ast_led_on($2, LOC(@2), LOC(@$)); } ;
expresion: expresion '+' termino { $$ = ast_binary('+', $1, $3, LOC(@$)); $$->as.binary.op_location = LOC(@2); }
         | expresion '-' termino { $$ = ast_binary('-', $1, $3, LOC(@$)); $$->as.binary.op_location = LOC(@2); }
         | termino { $$ = $1; } ;
termino: termino '*' factor { $$ = ast_binary('*', $1, $3, LOC(@$)); $$->as.binary.op_location = LOC(@2); }
       | termino '/' factor { $$ = ast_binary('/', $1, $3, LOC(@$)); $$->as.binary.op_location = LOC(@2); }
       | factor { $$ = $1; } ;
factor: ENTERO { $$ = ast_text(AST_INTEGER, $1, LOC(@$)); }
      | DECIMAL { $$ = ast_text(AST_DECIMAL, $1, LOC(@$)); }
      | ID { $$ = ast_text(AST_IDENTIFIER, $1, LOC(@$)); }
      | '(' expresion ')' { $$ = $2; } ;
%%
void yyerror(const char *message)
{
    if (!lexical_error)
        fprintf(stderr, "%s:%d:%d: error sintactico: %s\n", source_filename,
                yylloc.first_line, yylloc.first_column, message);
}
