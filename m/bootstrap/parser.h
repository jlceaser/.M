/*
 * parser.h — M language parser
 *
 * Turns tokens into AST. Recursive descent.
 * Reports errors with line:col context.
 */

#ifndef M_PARSER_H
#define M_PARSER_H

#include "ast.h"
#include "lexer.h"

typedef struct {
    Lexer lex;
    Token current;
    Token previous;
    int had_error;
    int panic_mode;

    /* Error info */
    char error_msg[256];
    int error_line;
    int error_col;
} Parser;

/* Initialize parser with source code */
void parser_init(Parser *p, const char *source);

/* Parse entire program. Returns NULL on failure. */
Program *parser_parse(Parser *p);

/* Parse a single expression (useful for testing) */
Expr *parser_parse_expr(Parser *p);

/* Parse a single statement */
Stmt *parser_parse_stmt(Parser *p);

/* Did parsing produce errors? */
int parser_had_error(const Parser *p);

/* Get error message */
const char *parser_error(const Parser *p);

#endif /* M_PARSER_H */
