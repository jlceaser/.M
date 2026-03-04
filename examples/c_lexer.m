// C Lexer — Machine reads C
// Phase 2: M understands other languages
// First step: tokenize C source code into structural tokens

// ── Character classification ─────────────────────────

fn is_digit(c: i32) -> bool { return c >= 48 && c <= 57; }
fn is_hex(c: i32) -> bool {
    if c >= 48 && c <= 57 { return true; }
    if c >= 65 && c <= 70 { return true; }
    if c >= 97 && c <= 102 { return true; }
    return false;
}
fn is_alpha(c: i32) -> bool {
    if c >= 65 && c <= 90 { return true; }
    if c >= 97 && c <= 122 { return true; }
    return c == 95;
}
fn is_alnum(c: i32) -> bool { return is_alpha(c) || is_digit(c); }
fn is_space(c: i32) -> bool { return c == 32 || c == 10 || c == 13 || c == 9; }

// ── C Token types ────────────────────────────────────

fn CTK_EOF() -> i32      { return 0; }
fn CTK_IDENT() -> i32    { return 1; }
fn CTK_INT_LIT() -> i32  { return 2; }
fn CTK_STR_LIT() -> i32  { return 3; }
fn CTK_CHAR_LIT() -> i32 { return 4; }
fn CTK_FLOAT_LIT() -> i32 { return 5; }
fn CTK_PREPROC() -> i32  { return 6; }

// C keywords (10-59)
fn CTK_AUTO() -> i32     { return 10; }
fn CTK_BREAK() -> i32    { return 11; }
fn CTK_CASE() -> i32     { return 12; }
fn CTK_CHAR() -> i32     { return 13; }
fn CTK_CONST() -> i32    { return 14; }
fn CTK_CONTINUE() -> i32 { return 15; }
fn CTK_DEFAULT() -> i32  { return 16; }
fn CTK_DO() -> i32       { return 17; }
fn CTK_DOUBLE() -> i32   { return 18; }
fn CTK_ELSE() -> i32     { return 19; }
fn CTK_ENUM() -> i32     { return 20; }
fn CTK_EXTERN() -> i32   { return 21; }
fn CTK_FLOAT() -> i32    { return 22; }
fn CTK_FOR() -> i32      { return 23; }
fn CTK_GOTO() -> i32     { return 24; }
fn CTK_IF() -> i32       { return 25; }
fn CTK_INT() -> i32      { return 26; }
fn CTK_LONG() -> i32     { return 27; }
fn CTK_REGISTER() -> i32 { return 28; }
fn CTK_RETURN() -> i32   { return 29; }
fn CTK_SHORT() -> i32    { return 30; }
fn CTK_SIGNED() -> i32   { return 31; }
fn CTK_SIZEOF() -> i32   { return 32; }
fn CTK_STATIC() -> i32   { return 33; }
fn CTK_STRUCT() -> i32   { return 34; }
fn CTK_SWITCH() -> i32   { return 35; }
fn CTK_TYPEDEF() -> i32  { return 36; }
fn CTK_UNION() -> i32    { return 37; }
fn CTK_UNSIGNED() -> i32 { return 38; }
fn CTK_VOID() -> i32     { return 39; }
fn CTK_VOLATILE() -> i32 { return 40; }
fn CTK_WHILE() -> i32    { return 41; }

// Operators and punctuation (60-99)
fn CTK_PLUS() -> i32     { return 60; }
fn CTK_MINUS() -> i32    { return 61; }
fn CTK_STAR() -> i32     { return 62; }
fn CTK_SLASH() -> i32    { return 63; }
fn CTK_MOD() -> i32      { return 64; }
fn CTK_AMP() -> i32      { return 65; }
fn CTK_PIPE() -> i32     { return 66; }
fn CTK_CARET() -> i32    { return 67; }
fn CTK_TILDE() -> i32    { return 68; }
fn CTK_NOT() -> i32      { return 69; }
fn CTK_ASSIGN() -> i32   { return 70; }
fn CTK_LT() -> i32       { return 71; }
fn CTK_GT() -> i32       { return 72; }
fn CTK_DOT() -> i32      { return 73; }
fn CTK_COMMA() -> i32    { return 74; }
fn CTK_SEMI() -> i32     { return 75; }
fn CTK_COLON() -> i32    { return 76; }
fn CTK_QUESTION() -> i32 { return 77; }
fn CTK_LPAREN() -> i32   { return 78; }
fn CTK_RPAREN() -> i32   { return 79; }
fn CTK_LBRACE() -> i32   { return 80; }
fn CTK_RBRACE() -> i32   { return 81; }
fn CTK_LBRACKET() -> i32 { return 82; }
fn CTK_RBRACKET() -> i32 { return 83; }

// Multi-char operators (100-129)
fn CTK_PLUS_ASSIGN() -> i32  { return 100; }
fn CTK_MINUS_ASSIGN() -> i32 { return 101; }
fn CTK_STAR_ASSIGN() -> i32  { return 102; }
fn CTK_SLASH_ASSIGN() -> i32 { return 103; }
fn CTK_MOD_ASSIGN() -> i32   { return 104; }
fn CTK_AMP_ASSIGN() -> i32   { return 105; }
fn CTK_PIPE_ASSIGN() -> i32  { return 106; }
fn CTK_CARET_ASSIGN() -> i32 { return 107; }
fn CTK_LSHIFT_ASSIGN() -> i32 { return 108; }
fn CTK_RSHIFT_ASSIGN() -> i32 { return 109; }
fn CTK_EQ() -> i32       { return 110; }
fn CTK_NEQ() -> i32      { return 111; }
fn CTK_LTE() -> i32      { return 112; }
fn CTK_GTE() -> i32      { return 113; }
fn CTK_AND() -> i32      { return 114; }
fn CTK_OR() -> i32       { return 115; }
fn CTK_INC() -> i32      { return 116; }
fn CTK_DEC() -> i32      { return 117; }
fn CTK_ARROW() -> i32    { return 118; }
fn CTK_LSHIFT() -> i32   { return 119; }
fn CTK_RSHIFT() -> i32   { return 120; }
fn CTK_ELLIPSIS() -> i32 { return 121; }

// ── Lexer state ──────────────────────────────────────

var c_tok_types: i32 = 0;
var c_tok_vals: i32 = 0;
var c_tok_lines: i32 = 0;
var c_tok_count: i32 = 0;

fn c_add_tok(typ: i32, val: string, line: i32) -> i32 {
    array_push(c_tok_types, typ);
    array_push(c_tok_vals, val);
    array_push(c_tok_lines, line);
    c_tok_count = c_tok_count + 1;
    return 0;
}

// ── Keyword classification ───────────────────────────

fn c_classify_word(w: string) -> i32 {
    if str_eq(w, "auto")     { return CTK_AUTO(); }
    if str_eq(w, "break")    { return CTK_BREAK(); }
    if str_eq(w, "case")     { return CTK_CASE(); }
    if str_eq(w, "char")     { return CTK_CHAR(); }
    if str_eq(w, "const")    { return CTK_CONST(); }
    if str_eq(w, "continue") { return CTK_CONTINUE(); }
    if str_eq(w, "default")  { return CTK_DEFAULT(); }
    if str_eq(w, "do")       { return CTK_DO(); }
    if str_eq(w, "double")   { return CTK_DOUBLE(); }
    if str_eq(w, "else")     { return CTK_ELSE(); }
    if str_eq(w, "enum")     { return CTK_ENUM(); }
    if str_eq(w, "extern")   { return CTK_EXTERN(); }
    if str_eq(w, "float")    { return CTK_FLOAT(); }
    if str_eq(w, "for")      { return CTK_FOR(); }
    if str_eq(w, "goto")     { return CTK_GOTO(); }
    if str_eq(w, "if")       { return CTK_IF(); }
    if str_eq(w, "int")      { return CTK_INT(); }
    if str_eq(w, "long")     { return CTK_LONG(); }
    if str_eq(w, "register") { return CTK_REGISTER(); }
    if str_eq(w, "return")   { return CTK_RETURN(); }
    if str_eq(w, "short")    { return CTK_SHORT(); }
    if str_eq(w, "signed")   { return CTK_SIGNED(); }
    if str_eq(w, "sizeof")   { return CTK_SIZEOF(); }
    if str_eq(w, "static")   { return CTK_STATIC(); }
    if str_eq(w, "struct")   { return CTK_STRUCT(); }
    if str_eq(w, "switch")   { return CTK_SWITCH(); }
    if str_eq(w, "typedef")  { return CTK_TYPEDEF(); }
    if str_eq(w, "union")    { return CTK_UNION(); }
    if str_eq(w, "unsigned") { return CTK_UNSIGNED(); }
    if str_eq(w, "void")     { return CTK_VOID(); }
    if str_eq(w, "volatile") { return CTK_VOLATILE(); }
    if str_eq(w, "while")    { return CTK_WHILE(); }
    return CTK_IDENT();
}

// ── Token type names (for display) ───────────────────

fn c_tok_name(t: i32) -> string {
    if t == CTK_EOF()      { return "EOF"; }
    if t == CTK_IDENT()    { return "IDENT"; }
    if t == CTK_INT_LIT()  { return "INT"; }
    if t == CTK_STR_LIT()  { return "STRING"; }
    if t == CTK_CHAR_LIT() { return "CHAR"; }
    if t == CTK_FLOAT_LIT() { return "FLOAT"; }
    if t == CTK_PREPROC()  { return "PREPROC"; }
    // Keywords
    if t >= 10 && t <= 41 {
        if t == CTK_AUTO()     { return "auto"; }
        if t == CTK_BREAK()    { return "break"; }
        if t == CTK_CASE()     { return "case"; }
        if t == CTK_CHAR()     { return "char"; }
        if t == CTK_CONST()    { return "const"; }
        if t == CTK_CONTINUE() { return "continue"; }
        if t == CTK_DEFAULT()  { return "default"; }
        if t == CTK_DO()       { return "do"; }
        if t == CTK_DOUBLE()   { return "double"; }
        if t == CTK_ELSE()     { return "else"; }
        if t == CTK_ENUM()     { return "enum"; }
        if t == CTK_EXTERN()   { return "extern"; }
        if t == CTK_FLOAT()    { return "float"; }
        if t == CTK_FOR()      { return "for"; }
        if t == CTK_GOTO()     { return "goto"; }
        if t == CTK_IF()       { return "if"; }
        if t == CTK_INT()      { return "int"; }
        if t == CTK_LONG()     { return "long"; }
        if t == CTK_REGISTER() { return "register"; }
        if t == CTK_RETURN()   { return "return"; }
        if t == CTK_SHORT()    { return "short"; }
        if t == CTK_SIGNED()   { return "signed"; }
        if t == CTK_SIZEOF()   { return "sizeof"; }
        if t == CTK_STATIC()   { return "static"; }
        if t == CTK_STRUCT()   { return "struct"; }
        if t == CTK_SWITCH()   { return "switch"; }
        if t == CTK_TYPEDEF()  { return "typedef"; }
        if t == CTK_UNION()    { return "union"; }
        if t == CTK_UNSIGNED() { return "unsigned"; }
        if t == CTK_VOID()     { return "void"; }
        if t == CTK_VOLATILE() { return "volatile"; }
        if t == CTK_WHILE()    { return "while"; }
    }
    // Operators
    if t == CTK_PLUS()    { return "+"; }
    if t == CTK_MINUS()   { return "-"; }
    if t == CTK_STAR()    { return "*"; }
    if t == CTK_SLASH()   { return "/"; }
    if t == CTK_MOD()     { return "%"; }
    if t == CTK_AMP()     { return "&"; }
    if t == CTK_PIPE()    { return "|"; }
    if t == CTK_CARET()   { return "^"; }
    if t == CTK_TILDE()   { return "~"; }
    if t == CTK_NOT()     { return "!"; }
    if t == CTK_ASSIGN()  { return "="; }
    if t == CTK_LT()      { return "<"; }
    if t == CTK_GT()      { return ">"; }
    if t == CTK_DOT()     { return "."; }
    if t == CTK_COMMA()   { return ","; }
    if t == CTK_SEMI()    { return ";"; }
    if t == CTK_COLON()   { return ":"; }
    if t == CTK_QUESTION() { return "?"; }
    if t == CTK_LPAREN()  { return "("; }
    if t == CTK_RPAREN()  { return ")"; }
    if t == CTK_LBRACE()  { return "{"; }
    if t == CTK_RBRACE()  { return "}"; }
    if t == CTK_LBRACKET() { return "["; }
    if t == CTK_RBRACKET() { return "]"; }
    // Multi-char
    if t == CTK_EQ()      { return "=="; }
    if t == CTK_NEQ()     { return "!="; }
    if t == CTK_LTE()     { return "<="; }
    if t == CTK_GTE()     { return ">="; }
    if t == CTK_AND()     { return "&&"; }
    if t == CTK_OR()      { return "||"; }
    if t == CTK_INC()     { return "++"; }
    if t == CTK_DEC()     { return "--"; }
    if t == CTK_ARROW()   { return "->"; }
    if t == CTK_LSHIFT()  { return "<<"; }
    if t == CTK_RSHIFT()  { return ">>"; }
    if t == CTK_ELLIPSIS() { return "..."; }
    if t == CTK_PLUS_ASSIGN()  { return "+="; }
    if t == CTK_MINUS_ASSIGN() { return "-="; }
    if t == CTK_STAR_ASSIGN()  { return "*="; }
    if t == CTK_SLASH_ASSIGN() { return "/="; }
    if t == CTK_MOD_ASSIGN()   { return "%="; }
    if t == CTK_AMP_ASSIGN()   { return "&="; }
    if t == CTK_PIPE_ASSIGN()  { return "|="; }
    if t == CTK_CARET_ASSIGN() { return "^="; }
    if t == CTK_LSHIFT_ASSIGN() { return "<<="; }
    if t == CTK_RSHIFT_ASSIGN() { return ">>="; }
    return "?";
}

// ── C Tokenizer ──────────────────────────────────────

fn c_tokenize(src: string) -> i32 {
    c_tok_types = array_new(0);
    c_tok_vals = array_new(0);
    c_tok_lines = array_new(0);
    c_tok_count = 0;
    var i: i32 = 0;
    var line: i32 = 1;

    while i < len(src) {
        let c: i32 = char_at(src, i);

        // Track newlines
        if c == 10 {
            line = line + 1;
            i = i + 1;
        } else if c == 13 {
            line = line + 1;
            i = i + 1;
            if i < len(src) && char_at(src, i) == 10 { i = i + 1; }
        // Whitespace
        } else if c == 32 || c == 9 {
            i = i + 1;
        // Line comment //
        } else if c == 47 && i + 1 < len(src) && char_at(src, i + 1) == 47 {
            while i < len(src) && char_at(src, i) != 10 { i = i + 1; }
        // Block comment /* */
        } else if c == 47 && i + 1 < len(src) && char_at(src, i + 1) == 42 {
            i = i + 2;
            var in_comment: i32 = 1;
            while i + 1 < len(src) && in_comment == 1 {
                if char_at(src, i) == 42 && char_at(src, i + 1) == 47 {
                    i = i + 2;
                    in_comment = 0;
                } else {
                    if char_at(src, i) == 10 { line = line + 1; }
                    i = i + 1;
                }
            }
        // Preprocessor directive
        } else if c == 35 {
            var start: i32 = i;
            while i < len(src) && char_at(src, i) != 10 {
                // Handle line continuation
                if char_at(src, i) == 92 && i + 1 < len(src) && char_at(src, i + 1) == 10 {
                    i = i + 2;
                    line = line + 1;
                } else {
                    i = i + 1;
                }
            }
            c_add_tok(CTK_PREPROC(), substr(src, start, i - start), line);
        // String literal
        } else if c == 34 {
            var start: i32 = i;
            i = i + 1;
            while i < len(src) && char_at(src, i) != 34 {
                if char_at(src, i) == 92 { i = i + 1; }
                i = i + 1;
            }
            if i < len(src) { i = i + 1; }
            c_add_tok(CTK_STR_LIT(), substr(src, start + 1, i - start - 2), line);
        // Character literal
        } else if c == 39 {
            var start: i32 = i;
            i = i + 1;
            while i < len(src) && char_at(src, i) != 39 {
                if char_at(src, i) == 92 { i = i + 1; }
                i = i + 1;
            }
            if i < len(src) { i = i + 1; }
            c_add_tok(CTK_CHAR_LIT(), substr(src, start + 1, i - start - 2), line);
        // Number literal
        } else if is_digit(c) {
            var start: i32 = i;
            var is_float: i32 = 0;
            // Hex: 0x...
            if c == 48 && i + 1 < len(src) && (char_at(src, i + 1) == 120 || char_at(src, i + 1) == 88) {
                i = i + 2;
                while i < len(src) && is_hex(char_at(src, i)) { i = i + 1; }
            } else {
                while i < len(src) && is_digit(char_at(src, i)) { i = i + 1; }
                // Float: digits.digits (must have digit after dot)
                if i < len(src) && char_at(src, i) == 46 && i + 1 < len(src) && is_digit(char_at(src, i + 1)) {
                    is_float = 1;
                    i = i + 1;
                    while i < len(src) && is_digit(char_at(src, i)) { i = i + 1; }
                }
            }
            // Suffixes: u, U, l, L, ll, LL, f, F
            while i < len(src) && (char_at(src, i) == 117 || char_at(src, i) == 85 || char_at(src, i) == 108 || char_at(src, i) == 76 || char_at(src, i) == 102 || char_at(src, i) == 70) {
                if char_at(src, i) == 102 || char_at(src, i) == 70 { is_float = 1; }
                i = i + 1;
            }
            let val: string = substr(src, start, i - start);
            if is_float == 1 {
                c_add_tok(CTK_FLOAT_LIT(), val, line);
            } else {
                c_add_tok(CTK_INT_LIT(), val, line);
            }
        // Identifier or keyword
        } else if is_alpha(c) {
            var start: i32 = i;
            while i < len(src) && is_alnum(char_at(src, i)) { i = i + 1; }
            let word: string = substr(src, start, i - start);
            c_add_tok(c_classify_word(word), word, line);
        // Operators
        } else if c == 43 {
            i = i + 1;
            if i < len(src) && char_at(src, i) == 43 { i = i + 1; c_add_tok(CTK_INC(), "++", line); }
            else if i < len(src) && char_at(src, i) == 61 { i = i + 1; c_add_tok(CTK_PLUS_ASSIGN(), "+=", line); }
            else { c_add_tok(CTK_PLUS(), "+", line); }
        } else if c == 45 {
            i = i + 1;
            if i < len(src) && char_at(src, i) == 45 { i = i + 1; c_add_tok(CTK_DEC(), "--", line); }
            else if i < len(src) && char_at(src, i) == 61 { i = i + 1; c_add_tok(CTK_MINUS_ASSIGN(), "-=", line); }
            else if i < len(src) && char_at(src, i) == 62 { i = i + 1; c_add_tok(CTK_ARROW(), "->", line); }
            else { c_add_tok(CTK_MINUS(), "-", line); }
        } else if c == 42 {
            i = i + 1;
            if i < len(src) && char_at(src, i) == 61 { i = i + 1; c_add_tok(CTK_STAR_ASSIGN(), "*=", line); }
            else { c_add_tok(CTK_STAR(), "*", line); }
        } else if c == 47 {
            i = i + 1;
            if i < len(src) && char_at(src, i) == 61 { i = i + 1; c_add_tok(CTK_SLASH_ASSIGN(), "/=", line); }
            else { c_add_tok(CTK_SLASH(), "/", line); }
        } else if c == 37 {
            i = i + 1;
            if i < len(src) && char_at(src, i) == 61 { i = i + 1; c_add_tok(CTK_MOD_ASSIGN(), "%=", line); }
            else { c_add_tok(CTK_MOD(), "%", line); }
        } else if c == 38 {
            i = i + 1;
            if i < len(src) && char_at(src, i) == 38 { i = i + 1; c_add_tok(CTK_AND(), "&&", line); }
            else if i < len(src) && char_at(src, i) == 61 { i = i + 1; c_add_tok(CTK_AMP_ASSIGN(), "&=", line); }
            else { c_add_tok(CTK_AMP(), "&", line); }
        } else if c == 124 {
            i = i + 1;
            if i < len(src) && char_at(src, i) == 124 { i = i + 1; c_add_tok(CTK_OR(), "||", line); }
            else if i < len(src) && char_at(src, i) == 61 { i = i + 1; c_add_tok(CTK_PIPE_ASSIGN(), "|=", line); }
            else { c_add_tok(CTK_PIPE(), "|", line); }
        } else if c == 94 {
            i = i + 1;
            if i < len(src) && char_at(src, i) == 61 { i = i + 1; c_add_tok(CTK_CARET_ASSIGN(), "^=", line); }
            else { c_add_tok(CTK_CARET(), "^", line); }
        } else if c == 126 { i = i + 1; c_add_tok(CTK_TILDE(), "~", line);
        } else if c == 33 {
            i = i + 1;
            if i < len(src) && char_at(src, i) == 61 { i = i + 1; c_add_tok(CTK_NEQ(), "!=", line); }
            else { c_add_tok(CTK_NOT(), "!", line); }
        } else if c == 61 {
            i = i + 1;
            if i < len(src) && char_at(src, i) == 61 { i = i + 1; c_add_tok(CTK_EQ(), "==", line); }
            else { c_add_tok(CTK_ASSIGN(), "=", line); }
        } else if c == 60 {
            i = i + 1;
            if i < len(src) && char_at(src, i) == 60 {
                i = i + 1;
                if i < len(src) && char_at(src, i) == 61 { i = i + 1; c_add_tok(CTK_LSHIFT_ASSIGN(), "<<=", line); }
                else { c_add_tok(CTK_LSHIFT(), "<<", line); }
            } else if i < len(src) && char_at(src, i) == 61 { i = i + 1; c_add_tok(CTK_LTE(), "<=", line); }
            else { c_add_tok(CTK_LT(), "<", line); }
        } else if c == 62 {
            i = i + 1;
            if i < len(src) && char_at(src, i) == 62 {
                i = i + 1;
                if i < len(src) && char_at(src, i) == 61 { i = i + 1; c_add_tok(CTK_RSHIFT_ASSIGN(), ">>=", line); }
                else { c_add_tok(CTK_RSHIFT(), ">>", line); }
            } else if i < len(src) && char_at(src, i) == 61 { i = i + 1; c_add_tok(CTK_GTE(), ">=", line); }
            else { c_add_tok(CTK_GT(), ">", line); }
        } else if c == 46 {
            i = i + 1;
            if i + 1 < len(src) && char_at(src, i) == 46 && char_at(src, i + 1) == 46 {
                i = i + 2;
                c_add_tok(CTK_ELLIPSIS(), "...", line);
            } else {
                c_add_tok(CTK_DOT(), ".", line);
            }
        // Single-char punctuation
        } else if c == 40  { i = i + 1; c_add_tok(CTK_LPAREN(), "(", line);
        } else if c == 41  { i = i + 1; c_add_tok(CTK_RPAREN(), ")", line);
        } else if c == 123 { i = i + 1; c_add_tok(CTK_LBRACE(), "{", line);
        } else if c == 125 { i = i + 1; c_add_tok(CTK_RBRACE(), "}", line);
        } else if c == 91  { i = i + 1; c_add_tok(CTK_LBRACKET(), "[", line);
        } else if c == 93  { i = i + 1; c_add_tok(CTK_RBRACKET(), "]", line);
        } else if c == 59  { i = i + 1; c_add_tok(CTK_SEMI(), ";", line);
        } else if c == 44  { i = i + 1; c_add_tok(CTK_COMMA(), ",", line);
        } else if c == 58  { i = i + 1; c_add_tok(CTK_COLON(), ":", line);
        } else if c == 63  { i = i + 1; c_add_tok(CTK_QUESTION(), "?", line);
        } else {
            // Unknown character — skip
            i = i + 1;
        }
    }

    c_add_tok(CTK_EOF(), "", line);
    return c_tok_count;
}

// ── Analysis helpers ─────────────────────────────────

fn c_count_type(target: i32) -> i32 {
    var count: i32 = 0;
    var i: i32 = 0;
    while i < c_tok_count {
        if array_get(c_tok_types, i) == target { count = count + 1; }
        i = i + 1;
    }
    return count;
}

fn c_count_keywords() -> i32 {
    var count: i32 = 0;
    var i: i32 = 0;
    while i < c_tok_count {
        let t: i32 = array_get(c_tok_types, i);
        if t >= 10 && t <= 41 { count = count + 1; }
        i = i + 1;
    }
    return count;
}

fn c_count_functions() -> i32 {
    // Heuristic: count patterns like "ident (" at top level (not inside braces)
    var count: i32 = 0;
    var depth: i32 = 0;
    var i: i32 = 0;
    while i < c_tok_count - 1 {
        let t: i32 = array_get(c_tok_types, i);
        if t == CTK_LBRACE() { depth = depth + 1; }
        if t == CTK_RBRACE() { depth = depth - 1; }
        // Function definition: return_type name ( ... ) {
        // Detect: IDENT followed by ( at depth 0
        if depth == 0 && t == CTK_IDENT() && array_get(c_tok_types, i + 1) == CTK_LPAREN() {
            // Check preceding token is a type keyword or ident (return type)
            if i > 0 {
                let prev: i32 = array_get(c_tok_types, i - 1);
                if prev == CTK_INT() || prev == CTK_VOID() || prev == CTK_CHAR() || prev == CTK_LONG() || prev == CTK_SHORT() || prev == CTK_DOUBLE() || prev == CTK_FLOAT() || prev == CTK_UNSIGNED() || prev == CTK_SIGNED() || prev == CTK_IDENT() || prev == CTK_STAR() || prev == CTK_STATIC() || prev == CTK_CONST() {
                    // Find matching ) then check for {
                    var j: i32 = i + 2;
                    var pdepth: i32 = 1;
                    while j < c_tok_count && pdepth > 0 {
                        if array_get(c_tok_types, j) == CTK_LPAREN() { pdepth = pdepth + 1; }
                        if array_get(c_tok_types, j) == CTK_RPAREN() { pdepth = pdepth - 1; }
                        j = j + 1;
                    }
                    // After ), check for { (definition, not declaration)
                    if j < c_tok_count && array_get(c_tok_types, j) == CTK_LBRACE() {
                        count = count + 1;
                    }
                }
            }
        }
        i = i + 1;
    }
    return count;
}

fn c_count_structs() -> i32 {
    var count: i32 = 0;
    var i: i32 = 0;
    while i < c_tok_count - 1 {
        if array_get(c_tok_types, i) == CTK_STRUCT() {
            // struct name { or struct {
            let next: i32 = array_get(c_tok_types, i + 1);
            if next == CTK_IDENT() || next == CTK_LBRACE() {
                count = count + 1;
            }
        }
        i = i + 1;
    }
    return count;
}

// ── Entry: driver + tests ─────────────────────────────

fn c_lexer_main() -> i32 {
    // Driver mode: tokenize a C file
    if argc() >= 1 {
        let path: string = argv(0);
        let src: string = read_file(path);
        if len(src) == 0 {
            print("error: cannot read ");
            println(path);
            return 1;
        }
        let count: i32 = c_tokenize(src);

        println(str_concat("=== C Lexer: ", path));
        print(int_to_str(count));
        println(" tokens");
        print(int_to_str(c_count_keywords()));
        println(" keywords");
        print(int_to_str(c_count_type(CTK_IDENT())));
        println(" identifiers");
        print(int_to_str(c_count_type(CTK_INT_LIT())));
        println(" integer literals");
        print(int_to_str(c_count_type(CTK_STR_LIT())));
        println(" string literals");
        print(int_to_str(c_count_type(CTK_PREPROC())));
        println(" preprocessor directives");
        print(int_to_str(c_count_functions()));
        println(" function definitions");
        print(int_to_str(c_count_structs()));
        println(" struct definitions");

        // Show first 20 tokens
        println("");
        println("First 20 tokens:");
        var i: i32 = 0;
        var limit: i32 = 20;
        if c_tok_count < limit { limit = c_tok_count; }
        while i < limit {
            let t: i32 = array_get(c_tok_types, i);
            let v: string = array_get(c_tok_vals, i);
            let ln: i32 = array_get(c_tok_lines, i);
            print("  L");
            print(int_to_str(ln));
            print("  ");
            print(c_tok_name(t));
            if t == CTK_IDENT() || t == CTK_INT_LIT() || t == CTK_STR_LIT() || t == CTK_CHAR_LIT() || t == CTK_PREPROC() || t == CTK_FLOAT_LIT() {
                print("(");
                print(v);
                print(")");
            }
            println("");
            i = i + 1;
        }

        return 0;
    }

    // ── Unit tests ───────────────────────────────────
    println("=== C Lexer Tests ===");
    var tests_run: i32 = 0;
    var tests_passed: i32 = 0;

    // Test 1: empty input
    tests_run = tests_run + 1;
    c_tokenize("");
    if c_tok_count == 1 && array_get(c_tok_types, 0) == CTK_EOF() {
        tests_passed = tests_passed + 1;
        println("  OK  empty input");
    } else { println("  FAIL empty input"); }

    // Test 2: keywords
    tests_run = tests_run + 1;
    c_tokenize("int void char return if else while for struct");
    if c_tok_count == 10 && array_get(c_tok_types, 0) == CTK_INT() && array_get(c_tok_types, 1) == CTK_VOID() && array_get(c_tok_types, 2) == CTK_CHAR() && array_get(c_tok_types, 3) == CTK_RETURN() {
        tests_passed = tests_passed + 1;
        println("  OK  keywords");
    } else { println("  FAIL keywords"); }

    // Test 3: operators
    tests_run = tests_run + 1;
    c_tokenize("+ - * / == != <= >= && || ++ -- ->");
    if c_tok_count == 14 && array_get(c_tok_types, 0) == CTK_PLUS() && array_get(c_tok_types, 4) == CTK_EQ() && array_get(c_tok_types, 10) == CTK_INC() && array_get(c_tok_types, 12) == CTK_ARROW() {
        tests_passed = tests_passed + 1;
        println("  OK  operators");
    } else { println("  FAIL operators"); }

    // Test 4: integer literals
    tests_run = tests_run + 1;
    c_tokenize("42 0 0xFF 1234");
    if c_tok_count == 5 && array_get(c_tok_types, 0) == CTK_INT_LIT() && str_eq(array_get(c_tok_vals, 0), "42") && str_eq(array_get(c_tok_vals, 2), "0xFF") {
        tests_passed = tests_passed + 1;
        println("  OK  integer literals");
    } else { println("  FAIL integer literals"); }

    // Test 5: string literal
    tests_run = tests_run + 1;
    c_tokenize("\"hello world\"");
    if c_tok_count == 2 && array_get(c_tok_types, 0) == CTK_STR_LIT() {
        tests_passed = tests_passed + 1;
        println("  OK  string literal");
    } else {
        print("  FAIL string literal (count=");
        print(int_to_str(c_tok_count));
        print(", type=");
        print(int_to_str(array_get(c_tok_types, 0)));
        println(")");
    }

    // Test 6: char literal
    tests_run = tests_run + 1;
    c_tokenize("'a' '\\n'");
    if c_tok_count == 3 && array_get(c_tok_types, 0) == CTK_CHAR_LIT() && array_get(c_tok_types, 1) == CTK_CHAR_LIT() {
        tests_passed = tests_passed + 1;
        println("  OK  char literals");
    } else { println("  FAIL char literals"); }

    // Test 7: preprocessor (#include <stdio.h> -> PREPROC EOF = 2)
    tests_run = tests_run + 1;
    c_tokenize("#include <stdio.h>");
    if c_tok_count == 2 && array_get(c_tok_types, 0) == CTK_PREPROC() {
        tests_passed = tests_passed + 1;
        println("  OK  preprocessor");
    } else {
        print("  FAIL preprocessor (count=");
        print(int_to_str(c_tok_count));
        println(")");
    }

    // Test 8: block comment
    tests_run = tests_run + 1;
    c_tokenize("int /* comment */ x;");
    if c_tok_count == 4 && array_get(c_tok_types, 0) == CTK_INT() && array_get(c_tok_types, 1) == CTK_IDENT() {
        tests_passed = tests_passed + 1;
        println("  OK  block comment");
    } else { println("  FAIL block comment"); }

    // Test 9: function pattern (INT IDENT LPAREN VOID RPAREN LBRACE RETURN INT_LIT SEMI RBRACE EOF = 11)
    tests_run = tests_run + 1;
    c_tokenize("int main(void) { return 0; }");
    if c_tok_count == 11 && array_get(c_tok_types, 0) == CTK_INT() && array_get(c_tok_types, 1) == CTK_IDENT() && array_get(c_tok_types, 2) == CTK_LPAREN() {
        tests_passed = tests_passed + 1;
        println("  OK  function pattern");
    } else {
        print("  FAIL function pattern (count=");
        print(int_to_str(c_tok_count));
        println(")");
    }

    // Test 10: struct definition (STRUCT IDENT LBRACE INT IDENT SEMI CONST CHAR STAR IDENT SEMI INT IDENT SEMI RBRACE SEMI EOF = 17)
    tests_run = tests_run + 1;
    c_tokenize("struct Token { int type; const char *start; int length; };");
    if c_tok_count == 17 && array_get(c_tok_types, 0) == CTK_STRUCT() && array_get(c_tok_types, 1) == CTK_IDENT() {
        tests_passed = tests_passed + 1;
        println("  OK  struct definition");
    } else {
        print("  FAIL struct definition (count=");
        print(int_to_str(c_tok_count));
        println(")");
    }

    // Test 11: pointer and arrow (IDENT ARROW IDENT INC SEMI EOF = 6)
    tests_run = tests_run + 1;
    c_tokenize("lex->current++;");
    if c_tok_count == 6 && array_get(c_tok_types, 0) == CTK_IDENT() && array_get(c_tok_types, 1) == CTK_ARROW() && array_get(c_tok_types, 2) == CTK_IDENT() && array_get(c_tok_types, 3) == CTK_INC() {
        tests_passed = tests_passed + 1;
        println("  OK  pointer arrow");
    } else {
        print("  FAIL pointer arrow (count=");
        print(int_to_str(c_tok_count));
        println(")");
    }

    // Test 12: real C file (M's own bootstrap lexer)
    tests_run = tests_run + 1;
    let lsrc: string = read_file("m/bootstrap/lexer.c");
    if len(lsrc) > 0 {
        let lcount: i32 = c_tokenize(lsrc);
        let lfuncs: i32 = c_count_functions();
        // lexer.c should have >500 tokens and >5 functions
        if lcount > 500 && lfuncs >= 5 {
            tests_passed = tests_passed + 1;
            print("  OK  lexer.c (");
            print(int_to_str(lcount));
            print(" tokens, ");
            print(int_to_str(lfuncs));
            println(" functions)");
        } else {
            print("  FAIL lexer.c (");
            print(int_to_str(lcount));
            print(" tokens, ");
            print(int_to_str(lfuncs));
            println(" functions)");
        }
    } else { println("  SKIP lexer.c (file not found)"); }

    // Test 13: all bootstrap files
    tests_run = tests_run + 1;
    let all_src: string = read_file("m/bootstrap/mc.c");
    let all2: string = read_file("m/bootstrap/lexer.c");
    let all3: string = read_file("m/bootstrap/parser.c");
    let all4: string = read_file("m/bootstrap/codegen.c");
    let all5: string = read_file("m/bootstrap/vm.c");
    let combined: string = str_concat(all_src, str_concat(all2, str_concat(all3, str_concat(all4, all5))));
    if len(combined) > 0 {
        let acount: i32 = c_tokenize(combined);
        let afuncs: i32 = c_count_functions();
        let astructs: i32 = c_count_structs();
        // All bootstrap files should have >5000 tokens, >50 functions
        if acount > 5000 && afuncs >= 40 {
            tests_passed = tests_passed + 1;
            print("  OK  all bootstrap (");
            print(int_to_str(acount));
            print(" tokens, ");
            print(int_to_str(afuncs));
            print(" functions, ");
            print(int_to_str(astructs));
            println(" structs)");
        } else {
            print("  FAIL all bootstrap (");
            print(int_to_str(acount));
            print(" tokens, ");
            print(int_to_str(afuncs));
            println(" functions)");
        }
    } else { println("  SKIP all bootstrap (files not found)"); }

    println("");
    print(int_to_str(tests_passed));
    print("/");
    print(int_to_str(tests_run));
    println(" tests passed");

    if tests_passed == tests_run {
        println("");
        println("M reads C. Phase 2 begins.");
    }

    return 0;
}

fn main() -> i32 {
    return c_lexer_main();
}
