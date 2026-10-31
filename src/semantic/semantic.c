#include "semantic.h"
#include <errno.h>
#include <inttypes.h>
#include <math.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>

typedef struct Symbol {
    const char *name;              /* Borrowed from the declaration AST node. */
    SemanticType type;
    SourceLocation location;
    AstNode *declaration;          /* Borrowed, usable by a future code generator. */
    struct Symbol *next;
} Symbol;

typedef struct {
    const char *filename;
    Symbol *symbols;
    int errors;
} Context;

static void error(Context *ctx, SourceLocation loc, const char *format, ...)
{
    va_list args;
    fprintf(stderr, "%s:%d:%d: error semantico: ", ctx->filename, loc.first_line, loc.first_column);
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
    fputc('\n', stderr);
    ++ctx->errors;
}

static Symbol *lookup(Context *ctx, const char *name)
{
    for (Symbol *s = ctx->symbols; s; s = s->next)
        if (strcmp(s->name, name) == 0) return s;
    return NULL;
}

static void insert(Context *ctx, AstNode *node, SemanticType type)
{
    Symbol *s = malloc(sizeof *s);
    if (!s) { fputs("Error: memoria insuficiente.\n", stderr); exit(EXIT_FAILURE); }
    s->name = node->as.declaration.name;
    s->location = node->as.declaration.name_location;
    s->declaration = node;
    s->type = type;
    s->next = ctx->symbols;
    ctx->symbols = s;
}

static const char *type_name(SemanticType type)
{
    return type == TYPE_INTEGER ? "entero" : "decimal";
}

static SemanticType expression(Context *ctx, AstNode *node)
{
    char *end;
    switch (node->kind) {
    case AST_INTEGER: {
        errno = 0;
        intmax_t value = strtoimax(node->as.text, &end, 10);
        if (errno == ERANGE || end == node->as.text || *end || value < INT32_MIN || value > INT32_MAX) {
            error(ctx, node->location, "literal entero fuera de rango i32: %s", node->as.text);
            return node->type = TYPE_ERROR;
        }
        node->literal_value.integer = (int32_t)value;
        return node->type = TYPE_INTEGER;
    }
    case AST_DECIMAL: {
        errno = 0;
        double value = strtod(node->as.text, &end);
        if (errno == ERANGE || end == node->as.text || *end || !isfinite(value)) {
            error(ctx, node->location, "literal decimal fuera de rango double: %s", node->as.text);
            return node->type = TYPE_ERROR;
        }
        node->literal_value.decimal = value;
        return node->type = TYPE_DECIMAL;
    }
    case AST_IDENTIFIER: {
        Symbol *s = lookup(ctx, node->as.text);
        if (!s) {
            error(ctx, node->location, "variable '%s' no declarada", node->as.text);
            return node->type = TYPE_ERROR;
        }
        return node->type = s->type;
    }
    case AST_BINARY: {
        SemanticType left = expression(ctx, node->as.binary.left);
        SemanticType right = expression(ctx, node->as.binary.right);
        if (left == TYPE_ERROR || right == TYPE_ERROR) return node->type = TYPE_ERROR;
        if (left != right) {
            error(ctx, node->as.binary.op_location, "tipos incompatibles en '%c': %s y %s",
                  node->as.binary.op, type_name(left), type_name(right));
            return node->type = TYPE_ERROR;
        }
        return node->type = left;
    }
    default:
        error(ctx, node->location, "nodo inesperado en expresion");
        return node->type = TYPE_ERROR;
    }
}

int semantic_analyze(AstNode *program, const char *filename)
{
    Context ctx = { filename, NULL, 0 };
    for (AstNode *s = program->as.program.statements; s; s = s->next) {
        if (s->kind == AST_LET) {
            Symbol *old = lookup(&ctx, s->as.declaration.name);
            if (old) {
                error(&ctx, s->as.declaration.name_location,
                      "declaracion duplicada de '%s' (primera declaracion en %d:%d)",
                      s->as.declaration.name, old->location.first_line, old->location.first_column);
            }
            SemanticType type = expression(&ctx, s->as.declaration.value);
            s->type = old ? TYPE_ERROR : type;
            if (!old && type != TYPE_ERROR) insert(&ctx, s, type);
        } else if (s->kind == AST_PRINT) {
            s->type = expression(&ctx, s->as.print.value);
        } else if (s->kind == AST_LED) {
            s->as.led.validated = 0;
            if (strcmp(s->as.led.pin, "13") != 0 || s->as.led.on != 1) {
                error(&ctx, s->as.led.pin_location, "solo se admite led 13 on");
                s->type = TYPE_ERROR;
            } else {
                s->as.led.validated = 1;
            }
        }
    }
    while (ctx.symbols) {
        Symbol *next = ctx.symbols->next;
        free(ctx.symbols);
        ctx.symbols = next;
    }
    return ctx.errors;
}
