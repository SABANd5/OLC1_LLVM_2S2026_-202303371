#ifndef SEMANTIC_H
#define SEMANTIC_H

#include "ast.h"

/* Annotates the AST. Returns the number of errors; the table does not outlive this call. */
int semantic_analyze(AstNode *program, const char *filename);

#endif
