#ifndef AST_H
#define AST_H

#include <stdio.h>

typedef struct {
    int first_line, first_column, last_line, last_column;
} SourceLocation;

typedef enum {
    AST_PROGRAM, AST_LET, AST_PRINT, AST_BINARY,
    AST_INTEGER, AST_DECIMAL, AST_IDENTIFIER
} AstKind;

typedef struct AstNode AstNode;
struct AstNode {
    AstKind kind;
    SourceLocation location;
    AstNode *next; /* Next statement; NULL for expressions. */
    union {
        struct { AstNode *statements; } program;
        struct { char *name; AstNode *value; } declaration;
        struct { AstNode *value; } print;
        struct { char op; AstNode *left, *right; } binary;
        char *text; /* Identifier or original literal spelling. */
    } as;
};

/* Constructors take ownership of their pointer arguments. */
AstNode *ast_program(AstNode *statements, SourceLocation location);
AstNode *ast_let(char *name, AstNode *value, SourceLocation location);
AstNode *ast_print_statement(AstNode *value, SourceLocation location);
AstNode *ast_binary(char op, AstNode *left, AstNode *right, SourceLocation location);
AstNode *ast_text(AstKind kind, char *text, SourceLocation location);
AstNode *ast_append(AstNode *head, AstNode *statement);
void ast_print(const AstNode *node, FILE *out);
void ast_free(AstNode *node);

#endif
