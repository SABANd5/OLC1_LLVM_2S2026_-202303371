#include "ast.h"
#include <stdlib.h>

static AstNode *new_node(AstKind kind, SourceLocation location)
{
    AstNode *node = calloc(1, sizeof *node);
    if (!node) {
        fputs("Error: memoria insuficiente.\n", stderr);
        exit(EXIT_FAILURE);
    }
    node->kind = kind;
    node->location = location;
    return node;
}

AstNode *ast_program(AstNode *statements, SourceLocation location)
{
    AstNode *node = new_node(AST_PROGRAM, location);
    node->as.program.statements = statements;
    return node;
}

AstNode *ast_let(char *name, AstNode *value, SourceLocation location)
{
    AstNode *node = new_node(AST_LET, location);
    node->as.declaration.name = name;
    node->as.declaration.value = value;
    return node;
}

AstNode *ast_print_statement(AstNode *value, SourceLocation location)
{
    AstNode *node = new_node(AST_PRINT, location);
    node->as.print.value = value;
    return node;
}

AstNode *ast_led_on(char *pin, SourceLocation pin_location, SourceLocation location)
{
    AstNode *node = new_node(AST_LED, location);
    node->as.led.pin = pin;
    node->as.led.pin_location = pin_location;
    node->as.led.on = 1;
    return node;
}

AstNode *ast_binary(char op, AstNode *left, AstNode *right, SourceLocation location)
{
    AstNode *node = new_node(AST_BINARY, location);
    node->as.binary.op = op;
    node->as.binary.left = left;
    node->as.binary.right = right;
    return node;
}

AstNode *ast_text(AstKind kind, char *text, SourceLocation location)
{
    AstNode *node = new_node(kind, location);
    node->as.text = text;
    return node;
}

AstNode *ast_append(AstNode *head, AstNode *statement)
{
    AstNode *tail = head;
    while (tail->next) tail = tail->next;
    tail->next = statement;
    return head;
}

static void print_tree(const AstNode *node, FILE *out, int depth)
{
    for (; node; node = node->next) {
        fprintf(out, "%*s", depth * 2, "");
        switch (node->kind) {
        case AST_PROGRAM:
            fputs("Programa\n", out);
            print_tree(node->as.program.statements, out, depth + 1);
            break;
        case AST_LET:
            fprintf(out, "Let %s\n", node->as.declaration.name);
            print_tree(node->as.declaration.value, out, depth + 1);
            break;
        case AST_PRINT:
            fputs("Print\n", out);
            print_tree(node->as.print.value, out, depth + 1);
            break;
        case AST_BINARY:
            fprintf(out, "Binaria %c\n", node->as.binary.op);
            print_tree(node->as.binary.left, out, depth + 1);
            print_tree(node->as.binary.right, out, depth + 1);
            break;
        case AST_INTEGER: fprintf(out, "Entero %s\n", node->as.text); break;
        case AST_DECIMAL: fprintf(out, "Decimal %s\n", node->as.text); break;
        case AST_IDENTIFIER: fprintf(out, "Identificador %s\n", node->as.text); break;
        case AST_LED: fprintf(out, "Led %s %s\n", node->as.led.pin, node->as.led.on ? "on" : "invalido"); break;
        }
    }
}

void ast_print(const AstNode *node, FILE *out) { print_tree(node, out, 0); }

void ast_free(AstNode *node)
{
    while (node) {
        AstNode *next = node->next;
        switch (node->kind) {
        case AST_PROGRAM: ast_free(node->as.program.statements); break;
        case AST_LET:
            free(node->as.declaration.name);
            ast_free(node->as.declaration.value);
            break;
        case AST_PRINT: ast_free(node->as.print.value); break;
        case AST_BINARY:
            ast_free(node->as.binary.left);
            ast_free(node->as.binary.right);
            break;
        case AST_INTEGER: case AST_DECIMAL: case AST_IDENTIFIER:
            free(node->as.text);
            break;
        case AST_LED: free(node->as.led.pin); break;
        }
        free(node);
        node = next;
    }
}
