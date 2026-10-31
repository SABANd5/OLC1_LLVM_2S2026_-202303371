#ifndef AST_H
#define AST_H

#include <stdio.h>
#include <stdint.h>

typedef struct {
    int first_line, first_column, last_line, last_column;
} SourceLocation;

typedef enum {
    AST_PROGRAM, AST_LET, AST_PRINT, AST_BINARY,
    AST_INTEGER, AST_DECIMAL, AST_IDENTIFIER, AST_LED
} AstKind;

typedef enum { TYPE_UNKNOWN, TYPE_ERROR, TYPE_INTEGER, TYPE_DECIMAL } SemanticType;

typedef struct AstNode AstNode;
struct AstNode {
    AstKind kind;
    SourceLocation location;
    SemanticType type; /* Set by semantic analysis; unknown before analysis. */
    union { int32_t integer; double decimal; } literal_value;
    AstNode *next; /* Next statement; NULL for expressions. */
    union {
        struct { AstNode *statements; } program;
        struct { char *name; SourceLocation name_location; AstNode *value; } declaration;
        struct { AstNode *value; } print;
        struct { char op; SourceLocation op_location; AstNode *left, *right; } binary;
        struct { char *pin; SourceLocation pin_location; int on, validated; } led;
        char *text; /* Identifier or original literal spelling. */
    } as;
};

/* Constructors take ownership of their pointer arguments. */
AstNode *ast_program(AstNode *statements, SourceLocation location);
AstNode *ast_let(char *name, AstNode *value, SourceLocation location);
AstNode *ast_print_statement(AstNode *value, SourceLocation location);
AstNode *ast_led_on(char *pin, SourceLocation pin_location, SourceLocation location);
AstNode *ast_binary(char op, AstNode *left, AstNode *right, SourceLocation location);
AstNode *ast_text(AstKind kind, char *text, SourceLocation location);
AstNode *ast_append(AstNode *head, AstNode *statement);
void ast_print(const AstNode *node, FILE *out);
void ast_free(AstNode *node);

#endif
