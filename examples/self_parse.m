// M self-parser: M code that parses M code
// Next step on the self-hosting path
// Uses the same recursive descent approach as eval.m
// but handles the full M language syntax

// ── Character classification ─────────────────────────

fn is_digit(c: i32) -> bool { return c >= 48 && c <= 57; }
fn is_alpha(c: i32) -> bool {
    if c >= 65 && c <= 90 { return true; }
    if c >= 97 && c <= 122 { return true; }
    return c == 95;
}
fn is_alnum(c: i32) -> bool { return is_alpha(c) || is_digit(c); }
fn is_space(c: i32) -> bool { return c == 32 || c == 10 || c == 13 || c == 9; }

// ── Token types ──────────────────────────────────────

fn TK_EOF() -> i32    { return 0; }
fn TK_IDENT() -> i32  { return 1; }
fn TK_NUM() -> i32    { return 2; }
fn TK_STR() -> i32    { return 3; }
fn TK_KW_FN() -> i32  { return 10; }
fn TK_KW_LET() -> i32 { return 11; }
fn TK_KW_VAR() -> i32 { return 12; }
fn TK_KW_IF() -> i32  { return 13; }
fn TK_KW_ELSE() -> i32 { return 14; }
fn TK_KW_WHILE() -> i32 { return 15; }
fn TK_KW_RETURN() -> i32 { return 16; }
fn TK_KW_TRUE() -> i32  { return 17; }
fn TK_KW_FALSE() -> i32 { return 18; }
fn TK_KW_STRUCT() -> i32 { return 19; }
// Type keywords
fn TK_KW_I32() -> i32   { return 20; }
fn TK_KW_I64() -> i32   { return 21; }
fn TK_KW_F64() -> i32   { return 22; }
fn TK_KW_BOOL() -> i32  { return 23; }
fn TK_KW_STRING() -> i32 { return 24; }
// Operators and punctuation
fn TK_PLUS() -> i32   { return 30; }
fn TK_MINUS() -> i32  { return 31; }
fn TK_STAR() -> i32   { return 32; }
fn TK_SLASH() -> i32  { return 33; }
fn TK_EQ() -> i32     { return 34; }  // ==
fn TK_NEQ() -> i32    { return 35; }  // !=
fn TK_LT() -> i32     { return 36; }
fn TK_GT() -> i32     { return 37; }
fn TK_LTE() -> i32    { return 38; }  // <=
fn TK_GTE() -> i32    { return 39; }  // >=
fn TK_ASSIGN() -> i32 { return 40; }  // =
fn TK_AND() -> i32    { return 41; }  // &&
fn TK_OR() -> i32     { return 42; }  // ||
fn TK_NOT() -> i32    { return 43; }  // !
fn TK_ARROW() -> i32  { return 44; }  // ->
fn TK_LPAREN() -> i32  { return 50; }
fn TK_RPAREN() -> i32  { return 51; }
fn TK_LBRACE() -> i32  { return 52; }
fn TK_RBRACE() -> i32  { return 53; }
fn TK_COLON() -> i32   { return 54; }
fn TK_SEMI() -> i32    { return 55; }
fn TK_COMMA() -> i32   { return 56; }
fn TK_DOT() -> i32     { return 57; }
fn TK_MOD() -> i32     { return 58; }  // %
fn TK_AMP() -> i32     { return 59; }  // & (address-of)

// ── Lexer state (globals) ────────────────────────────

var tok_types: i32 = 0;
var tok_vals: i32 = 0;
var tok_count: i32 = 0;
var tok_pos: i32 = 0;

// ── Keyword matching ─────────────────────────────────

fn classify_word(w: string) -> i32 {
    if str_eq(w, "fn")     { return TK_KW_FN(); }
    if str_eq(w, "let")    { return TK_KW_LET(); }
    if str_eq(w, "var")    { return TK_KW_VAR(); }
    if str_eq(w, "if")     { return TK_KW_IF(); }
    if str_eq(w, "else")   { return TK_KW_ELSE(); }
    if str_eq(w, "while")  { return TK_KW_WHILE(); }
    if str_eq(w, "return") { return TK_KW_RETURN(); }
    if str_eq(w, "true")   { return TK_KW_TRUE(); }
    if str_eq(w, "false")  { return TK_KW_FALSE(); }
    if str_eq(w, "struct") { return TK_KW_STRUCT(); }
    if str_eq(w, "i32")    { return TK_KW_I32(); }
    if str_eq(w, "i64")    { return TK_KW_I64(); }
    if str_eq(w, "f64")    { return TK_KW_F64(); }
    if str_eq(w, "bool")   { return TK_KW_BOOL(); }
    if str_eq(w, "string") { return TK_KW_STRING(); }
    return TK_IDENT();
}

// ── Tokenizer ────────────────────────────────────────

fn tokenize(src: string) -> i32 {
    tok_types = array_new(0);
    tok_vals = array_new(0);
    var i: i32 = 0;

    while i < len(src) {
        let c: i32 = char_at(src, i);

        // Skip whitespace
        if is_space(c) {
            i = i + 1;
        // Skip line comments
        } else if c == 47 && i + 1 < len(src) && char_at(src, i + 1) == 47 {
            while i < len(src) && char_at(src, i) != 10 {
                i = i + 1;
            }
        // String literals
        } else if c == 34 {
            var start: i32 = i + 1;
            i = i + 1;
            while i < len(src) && char_at(src, i) != 34 {
                if char_at(src, i) == 92 { i = i + 1; }
                i = i + 1;
            }
            array_push(tok_types, TK_STR());
            array_push(tok_vals, substr(src, start, i - start));
            if i < len(src) { i = i + 1; }
        // Numbers
        } else if is_digit(c) {
            var start: i32 = i;
            while i < len(src) && is_digit(char_at(src, i)) {
                i = i + 1;
            }
            array_push(tok_types, TK_NUM());
            array_push(tok_vals, substr(src, start, i - start));
        // Identifiers and keywords
        } else if is_alpha(c) {
            var start: i32 = i;
            while i < len(src) && is_alnum(char_at(src, i)) {
                i = i + 1;
            }
            let word: string = substr(src, start, i - start);
            array_push(tok_types, classify_word(word));
            array_push(tok_vals, word);
        // Two-character operators
        } else if c == 61 && i + 1 < len(src) && char_at(src, i + 1) == 61 {
            array_push(tok_types, TK_EQ()); array_push(tok_vals, "=="); i = i + 2;
        } else if c == 33 && i + 1 < len(src) && char_at(src, i + 1) == 61 {
            array_push(tok_types, TK_NEQ()); array_push(tok_vals, "!="); i = i + 2;
        } else if c == 60 && i + 1 < len(src) && char_at(src, i + 1) == 61 {
            array_push(tok_types, TK_LTE()); array_push(tok_vals, "<="); i = i + 2;
        } else if c == 62 && i + 1 < len(src) && char_at(src, i + 1) == 61 {
            array_push(tok_types, TK_GTE()); array_push(tok_vals, ">="); i = i + 2;
        } else if c == 45 && i + 1 < len(src) && char_at(src, i + 1) == 62 {
            array_push(tok_types, TK_ARROW()); array_push(tok_vals, "->"); i = i + 2;
        } else if c == 38 && i + 1 < len(src) && char_at(src, i + 1) == 38 {
            array_push(tok_types, TK_AND()); array_push(tok_vals, "&&"); i = i + 2;
        } else if c == 124 && i + 1 < len(src) && char_at(src, i + 1) == 124 {
            array_push(tok_types, TK_OR()); array_push(tok_vals, "||"); i = i + 2;
        // Single-character operators/punctuation
        } else if c == 43 { array_push(tok_types, TK_PLUS()); array_push(tok_vals, "+"); i = i + 1;
        } else if c == 45 { array_push(tok_types, TK_MINUS()); array_push(tok_vals, "-"); i = i + 1;
        } else if c == 42 { array_push(tok_types, TK_STAR()); array_push(tok_vals, "*"); i = i + 1;
        } else if c == 47 { array_push(tok_types, TK_SLASH()); array_push(tok_vals, "/"); i = i + 1;
        } else if c == 37 { array_push(tok_types, TK_MOD()); array_push(tok_vals, "%"); i = i + 1;
        } else if c == 33 { array_push(tok_types, TK_NOT()); array_push(tok_vals, "!"); i = i + 1;
        } else if c == 61 { array_push(tok_types, TK_ASSIGN()); array_push(tok_vals, "="); i = i + 1;
        } else if c == 60 { array_push(tok_types, TK_LT()); array_push(tok_vals, "<"); i = i + 1;
        } else if c == 62 { array_push(tok_types, TK_GT()); array_push(tok_vals, ">"); i = i + 1;
        } else if c == 38 { array_push(tok_types, TK_AMP()); array_push(tok_vals, "&"); i = i + 1;
        } else if c == 40 { array_push(tok_types, TK_LPAREN()); array_push(tok_vals, "("); i = i + 1;
        } else if c == 41 { array_push(tok_types, TK_RPAREN()); array_push(tok_vals, ")"); i = i + 1;
        } else if c == 123 { array_push(tok_types, TK_LBRACE()); array_push(tok_vals, "{"); i = i + 1;
        } else if c == 125 { array_push(tok_types, TK_RBRACE()); array_push(tok_vals, "}"); i = i + 1;
        } else if c == 58 { array_push(tok_types, TK_COLON()); array_push(tok_vals, ":"); i = i + 1;
        } else if c == 59 { array_push(tok_types, TK_SEMI()); array_push(tok_vals, ";"); i = i + 1;
        } else if c == 44 { array_push(tok_types, TK_COMMA()); array_push(tok_vals, ","); i = i + 1;
        } else if c == 46 { array_push(tok_types, TK_DOT()); array_push(tok_vals, "."); i = i + 1;
        } else {
            i = i + 1;
        }
    }

    array_push(tok_types, TK_EOF());
    array_push(tok_vals, "");
    tok_count = array_len(tok_types);
    tok_pos = 0;
    return tok_count;
}

// ── Parser helpers ───────────────────────────────────

fn peek() -> i32 {
    if tok_pos < tok_count { return array_get(tok_types, tok_pos); }
    return TK_EOF();
}

fn peek_val() -> string {
    if tok_pos < tok_count { return array_get(tok_vals, tok_pos); }
    return "";
}

fn advance() -> i32 {
    let t: i32 = peek();
    tok_pos = tok_pos + 1;
    return t;
}

fn advance_val() -> string {
    let v: string = peek_val();
    tok_pos = tok_pos + 1;
    return v;
}

fn expect(t: i32, msg: string) -> i32 {
    if peek() == t {
        advance();
        return 1;
    }
    print("PARSE ERROR: expected ");
    print(msg);
    print(" got '");
    print(peek_val());
    println("'");
    return 0;
}

fn match_tok(t: i32) -> bool {
    if peek() == t { advance(); return true; }
    return false;
}

// ── AST node types ───────────────────────────────────
// We represent the AST as arrays of node descriptors
// Each node: [kind, ...data indices]
// Instead of tree pointers, we use indices into a flat node array

// Node kinds
fn NK_INT_LIT() -> i32   { return 1; }
fn NK_STR_LIT() -> i32   { return 2; }
fn NK_BOOL_LIT() -> i32  { return 3; }
fn NK_IDENT() -> i32     { return 4; }
fn NK_BINARY() -> i32    { return 5; }
fn NK_UNARY() -> i32     { return 6; }
fn NK_CALL() -> i32      { return 7; }
fn NK_MEMBER() -> i32    { return 8; }
fn NK_LET() -> i32       { return 10; }
fn NK_ASSIGN() -> i32    { return 11; }
fn NK_RETURN() -> i32    { return 12; }
fn NK_IF() -> i32        { return 13; }
fn NK_WHILE() -> i32     { return 14; }
fn NK_BLOCK() -> i32     { return 15; }
fn NK_EXPR_STMT() -> i32 { return 16; }
fn NK_FN_DECL() -> i32   { return 20; }
fn NK_VAR_DECL() -> i32  { return 21; }
fn NK_STRUCT_DECL() -> i32 { return 22; }
fn NK_PROGRAM() -> i32   { return 30; }

// ── AST storage ──────────────────────────────────────
// Flat arrays — each node gets an index
// node_kinds[i] = kind of node i
// node_data[i]  = primary data (value index or child index)
// node_extra[i] = secondary data (second child, operator, etc)
// node_extra2[i] = third data field
// node_names[i] = name string for identifiers, functions, etc

var node_kinds: i32 = 0;
var node_data: i32 = 0;
var node_extra: i32 = 0;
var node_extra2: i32 = 0;
var node_names: i32 = 0;
var node_count: i32 = 0;

// Child list storage for blocks, args, params
var child_lists: i32 = 0;
var child_count: i32 = 0;

fn init_ast() -> i32 {
    node_kinds = array_new(0);
    node_data = array_new(0);
    node_extra = array_new(0);
    node_extra2 = array_new(0);
    node_names = array_new(0);
    child_lists = array_new(0);
    node_count = 0;
    child_count = 0;
    return 0;
}

fn new_node(kind: i32, data: i32, extra: i32, extra2: i32, name: string) -> i32 {
    let idx: i32 = node_count;
    array_push(node_kinds, kind);
    array_push(node_data, data);
    array_push(node_extra, extra);
    array_push(node_extra2, extra2);
    array_push(node_names, name);
    node_count = node_count + 1;
    return idx;
}

// Flush a local temp array into the contiguous child_lists
// Returns the start index in child_lists
fn flush_children(temp: i32) -> i32 {
    let start: i32 = child_count;
    var i: i32 = 0;
    while i < array_len(temp) {
        array_push(child_lists, array_get(temp, i));
        child_count = child_count + 1;
        i = i + 1;
    }
    return start;
}

// ── Expression parser (precedence climbing) ──────────

fn parse_expr() -> i32;
fn parse_stmt() -> i32;

fn parse_primary() -> i32 {
    let t: i32 = peek();

    if t == TK_NUM() {
        let v: string = advance_val();
        return new_node(NK_INT_LIT(), 0, 0, 0, v);
    }

    if t == TK_STR() {
        let v: string = advance_val();
        return new_node(NK_STR_LIT(), 0, 0, 0, v);
    }

    if t == TK_KW_TRUE() {
        advance();
        return new_node(NK_BOOL_LIT(), 1, 0, 0, "true");
    }

    if t == TK_KW_FALSE() {
        advance();
        return new_node(NK_BOOL_LIT(), 0, 0, 0, "false");
    }

    if t == TK_IDENT() {
        let name: string = advance_val();
        return new_node(NK_IDENT(), 0, 0, 0, name);
    }

    if t == TK_LPAREN() {
        advance();
        let inner: i32 = parse_expr();
        expect(TK_RPAREN(), "')'");
        return inner;
    }

    // Shouldn't reach here
    print("PARSE ERROR: unexpected token '");
    print(peek_val());
    println("'");
    advance();
    return new_node(NK_INT_LIT(), 0, 0, 0, "0");
}

fn parse_postfix() -> i32 {
    var node: i32 = parse_primary();

    while true {
        if peek() == TK_LPAREN() {
            // Function call: node(args...)
            advance();
            var args: i32 = array_new(0);
            while peek() != TK_RPAREN() && peek() != TK_EOF() {
                let arg: i32 = parse_expr();
                array_push(args, arg);
                if peek() != TK_RPAREN() { expect(TK_COMMA(), "','"); }
            }
            expect(TK_RPAREN(), "')'");
            let start: i32 = flush_children(args);
            let argc: i32 = array_len(args);
            // call node: data=callee, extra=start, extra2=argc
            node = new_node(NK_CALL(), node, start, argc, "");
        } else if peek() == TK_DOT() {
            // Member access: node.field
            advance();
            let field: string = advance_val();
            node = new_node(NK_MEMBER(), node, 0, 0, field);
        } else {
            return node;
        }
    }
    return node;
}

fn parse_unary() -> i32 {
    if peek() == TK_MINUS() {
        advance();
        let operand: i32 = parse_postfix();
        return new_node(NK_UNARY(), operand, 31, 0, "-");
    }
    if peek() == TK_NOT() {
        advance();
        let operand: i32 = parse_postfix();
        return new_node(NK_UNARY(), operand, 43, 0, "!");
    }
    if peek() == TK_AMP() {
        advance();
        let operand: i32 = parse_postfix();
        return new_node(NK_UNARY(), operand, 59, 0, "&");
    }
    if peek() == TK_STAR() {
        advance();
        let operand: i32 = parse_postfix();
        return new_node(NK_UNARY(), operand, 32, 0, "*");
    }
    return parse_postfix();
}

fn parse_factor() -> i32 {
    var left: i32 = parse_unary();
    while peek() == TK_STAR() || peek() == TK_SLASH() || peek() == TK_MOD() {
        let op: i32 = advance();
        let right: i32 = parse_unary();
        let op_name: string = "*";
        if op == TK_SLASH() { op_name = "/"; }
        if op == TK_MOD() { op_name = "%"; }
        left = new_node(NK_BINARY(), left, right, op, op_name);
    }
    return left;
}

fn parse_term() -> i32 {
    var left: i32 = parse_factor();
    while peek() == TK_PLUS() || peek() == TK_MINUS() {
        let op: i32 = advance();
        let right: i32 = parse_factor();
        let op_name: string = "+";
        if op == TK_MINUS() { op_name = "-"; }
        left = new_node(NK_BINARY(), left, right, op, op_name);
    }
    return left;
}

fn parse_comparison() -> i32 {
    var left: i32 = parse_term();
    while peek() == TK_LT() || peek() == TK_GT() || peek() == TK_LTE() || peek() == TK_GTE() {
        let op: i32 = advance();
        let right: i32 = parse_term();
        let op_name: string = "<";
        if op == TK_GT() { op_name = ">"; }
        if op == TK_LTE() { op_name = "<="; }
        if op == TK_GTE() { op_name = ">="; }
        left = new_node(NK_BINARY(), left, right, op, op_name);
    }
    return left;
}

fn parse_equality() -> i32 {
    var left: i32 = parse_comparison();
    while peek() == TK_EQ() || peek() == TK_NEQ() {
        let op: i32 = advance();
        let right: i32 = parse_comparison();
        let op_name: string = "==";
        if op == TK_NEQ() { op_name = "!="; }
        left = new_node(NK_BINARY(), left, right, op, op_name);
    }
    return left;
}

fn parse_and() -> i32 {
    var left: i32 = parse_equality();
    while peek() == TK_AND() {
        advance();
        let right: i32 = parse_equality();
        left = new_node(NK_BINARY(), left, right, TK_AND(), "&&");
    }
    return left;
}

fn parse_expr() -> i32 {
    var left: i32 = parse_and();
    while peek() == TK_OR() {
        advance();
        let right: i32 = parse_and();
        left = new_node(NK_BINARY(), left, right, TK_OR(), "||");
    }
    return left;
}

// ── Statement parser ─────────────────────────────────

fn parse_block() -> i32 {
    expect(TK_LBRACE(), "'{'");
    var stmts: i32 = array_new(0);
    while peek() != TK_RBRACE() && peek() != TK_EOF() {
        let s: i32 = parse_stmt();
        array_push(stmts, s);
    }
    expect(TK_RBRACE(), "'}'");
    let start: i32 = flush_children(stmts);
    return new_node(NK_BLOCK(), start, array_len(stmts), 0, "");
}

fn parse_type() -> string {
    let t: i32 = peek();
    if t == TK_KW_I32()    { advance(); return "i32"; }
    if t == TK_KW_I64()    { advance(); return "i64"; }
    if t == TK_KW_F64()    { advance(); return "f64"; }
    if t == TK_KW_BOOL()   { advance(); return "bool"; }
    if t == TK_KW_STRING() { advance(); return "string"; }
    if t == TK_IDENT()     { let name: string = advance_val(); return name; }
    return "unknown";
}

fn parse_stmt() -> i32 {
    // let/var declaration
    if peek() == TK_KW_LET() || peek() == TK_KW_VAR() {
        let is_var: i32 = 0;
        if peek() == TK_KW_VAR() { is_var = 1; }
        advance();
        let name: string = advance_val();
        // Optional type
        var type_name: string = "";
        if match_tok(TK_COLON()) {
            type_name = parse_type();
        }
        // Optional init
        var init: i32 = 0 - 1;
        if match_tok(TK_ASSIGN()) {
            init = parse_expr();
        }
        expect(TK_SEMI(), "';'");
        return new_node(NK_LET(), init, is_var, 0, name);
    }

    // return
    if peek() == TK_KW_RETURN() {
        advance();
        var val: i32 = 0 - 1;
        if peek() != TK_SEMI() {
            val = parse_expr();
        }
        expect(TK_SEMI(), "';'");
        return new_node(NK_RETURN(), val, 0, 0, "");
    }

    // if/else
    if peek() == TK_KW_IF() {
        advance();
        let cond: i32 = parse_expr();
        let then_blk: i32 = parse_block();
        var else_blk: i32 = 0 - 1;
        if match_tok(TK_KW_ELSE()) {
            if peek() == TK_KW_IF() {
                // else if — wrap in a block-like node
                let elif: i32 = parse_stmt();
                else_blk = elif;
            } else {
                else_blk = parse_block();
            }
        }
        return new_node(NK_IF(), cond, then_blk, else_blk, "");
    }

    // while
    if peek() == TK_KW_WHILE() {
        advance();
        let cond: i32 = parse_expr();
        let body: i32 = parse_block();
        return new_node(NK_WHILE(), cond, body, 0, "");
    }

    // block
    if peek() == TK_LBRACE() {
        return parse_block();
    }

    // expression statement or assignment
    let expr: i32 = parse_expr();
    if match_tok(TK_ASSIGN()) {
        let val: i32 = parse_expr();
        expect(TK_SEMI(), "';'");
        return new_node(NK_ASSIGN(), expr, val, 0, "");
    }
    expect(TK_SEMI(), "';'");
    return new_node(NK_EXPR_STMT(), expr, 0, 0, "");
}

// ── Declaration parser ───────────────────────────────

fn parse_fn_decl() -> i32 {
    // 'fn' already consumed
    let name: string = advance_val();
    expect(TK_LPAREN(), "'('");

    // Parameters
    var params: i32 = array_new(0);
    while peek() != TK_RPAREN() && peek() != TK_EOF() {
        let pname: string = advance_val();
        expect(TK_COLON(), "':'");
        let ptype: string = parse_type();
        let pnode: i32 = new_node(NK_LET(), 0 - 1, 0, 0, pname);
        array_push(params, pnode);
        if peek() != TK_RPAREN() { expect(TK_COMMA(), "','"); }
    }
    expect(TK_RPAREN(), "')'");

    // Return type
    var ret_type: string = "void";
    if match_tok(TK_ARROW()) {
        ret_type = parse_type();
    }

    // Body (or forward declaration)
    var body: i32 = 0 - 1;
    if peek() == TK_SEMI() {
        advance();
    } else {
        body = parse_block();
    }

    let param_start: i32 = flush_children(params);
    let param_count: i32 = array_len(params);
    // fn_decl: data=body, extra=param_start, extra2=param_count
    return new_node(NK_FN_DECL(), body, param_start, param_count, name);
}

fn parse_global_var() -> i32 {
    // 'var' already consumed
    let name: string = advance_val();
    var type_name: string = "";
    if match_tok(TK_COLON()) {
        type_name = parse_type();
    }
    var init: i32 = 0 - 1;
    if match_tok(TK_ASSIGN()) {
        init = parse_expr();
    }
    expect(TK_SEMI(), "';'");
    return new_node(NK_VAR_DECL(), init, 0, 0, name);
}

fn parse_struct_decl() -> i32 {
    // 'struct' already consumed
    let name: string = advance_val();
    expect(TK_LBRACE(), "'{'");
    var fields: i32 = array_new(0);
    while peek() != TK_RBRACE() && peek() != TK_EOF() {
        let fname: string = advance_val();
        expect(TK_COLON(), "':'");
        let ftype: string = parse_type();
        let fnode: i32 = new_node(NK_LET(), 0 - 1, 0, 0, fname);
        array_push(fields, fnode);
        if peek() != TK_RBRACE() { expect(TK_COMMA(), "','"); }
    }
    expect(TK_RBRACE(), "'}'");
    let field_start: i32 = flush_children(fields);
    return new_node(NK_STRUCT_DECL(), field_start, array_len(fields), 0, name);
}

fn parse_program() -> i32 {
    var decls: i32 = array_new(0);

    while peek() != TK_EOF() {
        if peek() == TK_KW_FN() {
            advance();
            let d: i32 = parse_fn_decl();
            array_push(decls, d);
        } else if peek() == TK_KW_VAR() {
            advance();
            let d: i32 = parse_global_var();
            array_push(decls, d);
        } else if peek() == TK_KW_STRUCT() {
            advance();
            let d: i32 = parse_struct_decl();
            array_push(decls, d);
        } else {
            print("PARSE ERROR: unexpected at top level: '");
            print(peek_val());
            println("'");
            advance();
        }
    }

    let start: i32 = flush_children(decls);
    return new_node(NK_PROGRAM(), start, array_len(decls), 0, "");
}

// ── AST printer (for verification) ──────────────────

var print_depth: i32 = 0;

fn indent() -> i32 {
    var i: i32 = 0;
    while i < print_depth {
        print("  ");
        i = i + 1;
    }
    return 0;
}

fn print_node(idx: i32) -> i32 {
    if idx < 0 { return 0; }
    let kind: i32 = array_get(node_kinds, idx);
    let data: i32 = array_get(node_data, idx);
    let extra: i32 = array_get(node_extra, idx);
    let extra2: i32 = array_get(node_extra2, idx);
    let name: string = array_get(node_names, idx);

    indent();

    if kind == NK_PROGRAM() {
        println("Program");
        print_depth = print_depth + 1;
        var i: i32 = 0;
        while i < extra {
            print_node(array_get(child_lists, data + i));
            i = i + 1;
        }
        print_depth = print_depth - 1;
    } else if kind == NK_FN_DECL() {
        print("FnDecl: ");
        print(name);
        print(" (");
        print(extra2);
        println(" params)");
        print_depth = print_depth + 1;
        print_node(data);
        print_depth = print_depth - 1;
    } else if kind == NK_VAR_DECL() {
        print("GlobalVar: ");
        println(name);
        if data >= 0 {
            print_depth = print_depth + 1;
            print_node(data);
            print_depth = print_depth - 1;
        }
    } else if kind == NK_STRUCT_DECL() {
        print("Struct: ");
        print(name);
        print(" (");
        print(extra);
        println(" fields)");
    } else if kind == NK_BLOCK() {
        print("Block (");
        print(extra);
        println(" stmts)");
        print_depth = print_depth + 1;
        var i: i32 = 0;
        while i < extra {
            print_node(array_get(child_lists, data + i));
            i = i + 1;
        }
        print_depth = print_depth - 1;
    } else if kind == NK_LET() {
        if extra == 1 {
            print("Var: ");
        } else {
            print("Let: ");
        }
        println(name);
        if data >= 0 {
            print_depth = print_depth + 1;
            print_node(data);
            print_depth = print_depth - 1;
        }
    } else if kind == NK_ASSIGN() {
        println("Assign");
        print_depth = print_depth + 1;
        print_node(data);
        print_node(extra);
        print_depth = print_depth - 1;
    } else if kind == NK_RETURN() {
        println("Return");
        if data >= 0 {
            print_depth = print_depth + 1;
            print_node(data);
            print_depth = print_depth - 1;
        }
    } else if kind == NK_IF() {
        println("If");
        print_depth = print_depth + 1;
        indent(); println("cond:");
        print_depth = print_depth + 1;
        print_node(data);
        print_depth = print_depth - 1;
        indent(); println("then:");
        print_depth = print_depth + 1;
        print_node(extra);
        print_depth = print_depth - 1;
        if extra2 >= 0 {
            indent(); println("else:");
            print_depth = print_depth + 1;
            print_node(extra2);
            print_depth = print_depth - 1;
        }
        print_depth = print_depth - 1;
    } else if kind == NK_WHILE() {
        println("While");
        print_depth = print_depth + 1;
        indent(); println("cond:");
        print_depth = print_depth + 1;
        print_node(data);
        print_depth = print_depth - 1;
        indent(); println("body:");
        print_depth = print_depth + 1;
        print_node(extra);
        print_depth = print_depth - 1;
        print_depth = print_depth - 1;
    } else if kind == NK_EXPR_STMT() {
        println("ExprStmt");
        print_depth = print_depth + 1;
        print_node(data);
        print_depth = print_depth - 1;
    } else if kind == NK_CALL() {
        print("Call (");
        print(extra2);
        println(" args)");
        print_depth = print_depth + 1;
        indent(); println("callee:");
        print_depth = print_depth + 1;
        print_node(data);
        print_depth = print_depth - 1;
        if extra2 > 0 {
            indent(); println("args:");
            print_depth = print_depth + 1;
            var i: i32 = 0;
            while i < extra2 {
                print_node(array_get(child_lists, extra + i));
                i = i + 1;
            }
            print_depth = print_depth - 1;
        }
        print_depth = print_depth - 1;
    } else if kind == NK_BINARY() {
        print("Binary: ");
        println(name);
        print_depth = print_depth + 1;
        print_node(data);
        print_node(extra);
        print_depth = print_depth - 1;
    } else if kind == NK_UNARY() {
        print("Unary: ");
        println(name);
        print_depth = print_depth + 1;
        print_node(data);
        print_depth = print_depth - 1;
    } else if kind == NK_MEMBER() {
        print("Member: .");
        println(name);
        print_depth = print_depth + 1;
        print_node(data);
        print_depth = print_depth - 1;
    } else if kind == NK_INT_LIT() {
        print("Int: ");
        println(name);
    } else if kind == NK_STR_LIT() {
        print("Str: \"");
        print(name);
        println("\"");
    } else if kind == NK_BOOL_LIT() {
        print("Bool: ");
        println(name);
    } else if kind == NK_IDENT() {
        print("Ident: ");
        println(name);
    } else {
        print("Unknown(");
        print(kind);
        println(")");
    }

    return 0;
}

// ── Test: parse a small M program ────────────────────

fn test_parse(src: string, label: string) -> i32 {
    println(label);
    init_ast();
    tokenize(src);
    let root: i32 = parse_program();
    print_depth = 0;
    print_node(root);
    println("");
    return 1;
}

fn main() -> i32 {
    println("=== M Self-Parser ===");
    println("");

    test_parse(
        "fn add(a: i32, b: i32) -> i32 { return a + b; }",
        "--- Simple function ---"
    );

    test_parse(
        "fn fib(n: i32) -> i32 { if n <= 1 { return n; } return fib(n - 1) + fib(n - 2); }",
        "--- Fibonacci ---"
    );

    test_parse(
        "var counter: i32 = 0; fn inc() -> i32 { counter = counter + 1; return counter; } fn main() -> i32 { inc(); inc(); return counter; }",
        "--- Global var + mutation ---"
    );

    test_parse(
        "fn main() -> i32 { var i: i32 = 0; while i < 10 { if i == 5 { println(\"halfway\"); } i = i + 1; } return i; }",
        "--- While + if ---"
    );

    // The ultimate test: M parses M
    println("--- Self-parse: reading own source ---");
    let src: string = read_file("examples/self_parse.m");
    init_ast();
    tokenize(src);
    print("Tokens: "); println(tok_count);
    let root: i32 = parse_program();
    let kind: i32 = array_get(node_kinds, root);
    let decl_count: i32 = array_get(node_extra, root);
    print("Declarations: "); println(decl_count);
    print("AST nodes: "); println(node_count);
    println("");
    println("M parses M. The scaffold shrinks.");
    return 0;
}
