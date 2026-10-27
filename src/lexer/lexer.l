%option noyywrap nounput noinput never-interactive nodefault
%{
#include "parser.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern const char *source_filename;
int lexical_error = 0;
static int line = 1, column = 1;
static void locate(const char *text, int length)
{
    yylloc.first_line = line; yylloc.first_column = column;
    for (int i = 0; i < length; ++i) {
        yylloc.last_line = line; yylloc.last_column = column;
        if (text[i] == '\n') { ++line; column = 1; }
        else if (text[i] != '\r') ++column;
    }
}
#define YY_USER_ACTION locate(yytext, yyleng);
static char *copy_text(const char *text, size_t length)
{
    char *copy = malloc(length + 1);
    if (!copy) { fputs("Error: memoria insuficiente.\n", stderr); exit(EXIT_FAILURE); }
    memcpy(copy, text, length);
    copy[length] = '\0';
    return copy;
}
%}
%%
"let"                  { return LET; }
"print"                { return PRINT; }
[A-Za-z_][A-Za-z_0-9]* { yylval.text = copy_text(yytext, yyleng); return ID; }
[0-9]+\.[0-9]+         { yylval.text = copy_text(yytext, yyleng); return DECIMAL; }
[0-9]+                 { yylval.text = copy_text(yytext, yyleng); return ENTERO; }
[+*/=();-]             { return (unsigned char)yytext[0]; }
[ \t\r\n]+             { /* Separadores. */ }
.                      { fprintf(stderr, "%s:%d:%d: error lexico: caracter invalido '%s'\n",
                                source_filename, yylloc.first_line, yylloc.first_column, yytext);
                         lexical_error = 1; return INVALID; }
<<EOF>>                { yylloc.first_line = yylloc.last_line = line;
                         yylloc.first_column = yylloc.last_column = column; return 0; }
%%
