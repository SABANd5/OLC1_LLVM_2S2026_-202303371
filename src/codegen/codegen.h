#ifndef CODEGEN_H
#define CODEGEN_H
#include <stdio.h>
#include "ast.h"
int codegen_write(const AstNode *program, const char *output, FILE *input);
#endif
