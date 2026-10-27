#include <stdio.h>
#include <stdlib.h>
#include "ast.h"
#include "parser.tab.h"

extern FILE *yyin;
extern AstNode *ast_root;
extern int lexical_error;
int yylex_destroy(void);
const char *source_filename;

int main(int argc, char **argv)
{
    if (argc != 2) {
        fprintf(stderr, "Uso: %s archivo_fuente\n", argv[0]);
        return EXIT_FAILURE;
    }
    source_filename = argv[1];
    yyin = fopen(source_filename, "rb");
    if (!yyin) { perror(source_filename); return EXIT_FAILURE; }
    FILE *input = yyin; /* yylex_destroy resets the global yyin. */
    int result = yyparse();
    if (ferror(yyin)) {
        fprintf(stderr, "%s: error de lectura\n", source_filename);
        result = 1;
    }
    if (!result && !lexical_error && ast_root) ast_print(ast_root, stdout);
    else result = 1;
    ast_free(ast_root);
    yylex_destroy();
    if (fclose(input) != 0) { perror(source_filename); result = 1; }
    return result ? EXIT_FAILURE : EXIT_SUCCESS;
}
