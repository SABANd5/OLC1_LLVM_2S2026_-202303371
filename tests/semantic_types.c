#include "ast.h"
#include "semantic.h"
#include <assert.h>
#include <stdlib.h>
#include <string.h>

static char *copy(const char *s)
{
    char *p = malloc(strlen(s) + 1);
    assert(p != NULL);
    return strcpy(p, s);
}

int main(void)
{
    SourceLocation loc = {1, 1, 1, 1};
    AstNode *integer = ast_text(AST_INTEGER, copy("2147483647"), loc);
    AstNode *decl = ast_let(copy("x"), integer, loc);
    AstNode *identifier = ast_text(AST_IDENTIFIER, copy("x"), loc);
    AstNode *two = ast_text(AST_INTEGER, copy("2"), loc);
    AstNode *division = ast_binary('/', identifier, two, loc);
    AstNode *print = ast_print_statement(division, loc);
    AstNode *decimal = ast_text(AST_DECIMAL, copy("2.5"), loc);
    AstNode *decl_dec = ast_let(copy("d"), decimal, loc);
    AstNode *dec_id = ast_text(AST_IDENTIFIER, copy("d"), loc);
    AstNode *dec_value = ast_text(AST_DECIMAL, copy("1.5"), loc);
    AstNode *sum = ast_binary('+', dec_id, dec_value, loc);
    AstNode *print_dec = ast_print_statement(sum, loc);
    ast_append(decl, print);
    ast_append(decl, decl_dec);
    ast_append(decl, print_dec);
    AstNode *program = ast_program(decl, loc);
    assert(semantic_analyze(program, "test") == 0);
    assert(integer->literal_value.integer == INT32_MAX);
    assert(decimal->literal_value.decimal == 2.5);
    assert(decl->type == TYPE_INTEGER && integer->type == TYPE_INTEGER);
    assert(identifier->type == TYPE_INTEGER && two->type == TYPE_INTEGER);
    assert(division->type == TYPE_INTEGER && print->type == TYPE_INTEGER);
    assert(decl_dec->type == TYPE_DECIMAL && decimal->type == TYPE_DECIMAL);
    assert(dec_id->type == TYPE_DECIMAL && dec_value->type == TYPE_DECIMAL);
    assert(sum->type == TYPE_DECIMAL && print_dec->type == TYPE_DECIMAL);
    ast_free(program);
    return 0;
}
