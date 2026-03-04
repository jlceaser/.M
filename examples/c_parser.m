// c_parser.m — C structural parser written in M
// Phase 2: M reads C code structure
//
// Parses C token streams into structural representation:
// - Function definitions/declarations with signatures
// - Struct definitions with fields
// - Enum definitions with constants
// - Typedefs
// - Global variables
// - Preprocessor directives
//
// Usage:
//   mc.exe self_codegen.m c_parser.m              -- run tests
//   mc.exe self_codegen.m c_parser.m <file.c>     -- analyze file

use "c_lexer.m";

// ── C AST Node Kinds ────────────────────────────────

fn CNK_PROGRAM() -> i32      { return 100; }
fn CNK_PREPROC() -> i32      { return 101; }
fn CNK_FUNC_DEF() -> i32     { return 102; }
fn CNK_FUNC_DECL() -> i32    { return 103; }
fn CNK_STRUCT_DEF() -> i32   { return 104; }
fn CNK_ENUM_DEF() -> i32     { return 105; }
fn CNK_TYPEDEF() -> i32      { return 106; }
fn CNK_GLOBAL_VAR() -> i32   { return 107; }
fn CNK_FIELD() -> i32        { return 108; }
fn CNK_ENUM_CONST() -> i32   { return 109; }
fn CNK_PARAM() -> i32        { return 110; }
fn CNK_FORWARD_DECL() -> i32 { return 111; }

// ── C AST Storage (flat arrays) ─────────────────────

var cn_kinds: i32 = 0;
var cn_d1: i32 = 0;       // primary data (child index, count, etc.)
var cn_d2: i32 = 0;       // secondary data
var cn_d3: i32 = 0;       // tertiary data
var cn_names: i32 = 0;    // identifier/name
var cn_types: i32 = 0;    // type string
var cn_count: i32 = 0;
var cn_children: i32 = 0;
var cn_child_count: i32 = 0;

fn cp_init_ast() -> i32 {
    cn_kinds = array_new(0);
    cn_d1 = array_new(0);
    cn_d2 = array_new(0);
    cn_d3 = array_new(0);
    cn_names = array_new(0);
    cn_types = array_new(0);
    cn_children = array_new(0);
    cn_count = 0;
    cn_child_count = 0;
    return 0;
}

fn cn_new(kind: i32, name: string, type_s: string, d1: i32, d2: i32, d3: i32) -> i32 {
    let idx: i32 = cn_count;
    array_push(cn_kinds, kind);
    array_push(cn_names, name);
    array_push(cn_types, type_s);
    array_push(cn_d1, d1);
    array_push(cn_d2, d2);
    array_push(cn_d3, d3);
    cn_count = cn_count + 1;
    return idx;
}

fn cnk(i: i32) -> i32     { return array_get(cn_kinds, i); }
fn cnn(i: i32) -> string   { return array_get(cn_names, i); }
fn cnt(i: i32) -> string   { return array_get(cn_types, i); }
fn cnd1(i: i32) -> i32    { return array_get(cn_d1, i); }
fn cnd2(i: i32) -> i32    { return array_get(cn_d2, i); }
fn cnd3(i: i32) -> i32    { return array_get(cn_d3, i); }

fn cn_flush(temp: i32) -> i32 {
    let start: i32 = cn_child_count;
    var i: i32 = 0;
    while i < array_len(temp) {
        array_push(cn_children, array_get(temp, i));
        cn_child_count = cn_child_count + 1;
        i = i + 1;
    }
    return start;
}

fn cn_child(start: i32, i: i32) -> i32 {
    return array_get(cn_children, start + i);
}

// ── Parser State ────────────────────────────────────

var cp_pos: i32 = 0;
var cp_type_names: i32 = 0;

fn cp_init() -> i32 {
    cp_pos = 0;
    cp_type_names = array_new(0);
    // Register built-in C type names
    array_push(cp_type_names, "void");
    array_push(cp_type_names, "char");
    array_push(cp_type_names, "short");
    array_push(cp_type_names, "int");
    array_push(cp_type_names, "long");
    array_push(cp_type_names, "float");
    array_push(cp_type_names, "double");
    array_push(cp_type_names, "signed");
    array_push(cp_type_names, "unsigned");
    array_push(cp_type_names, "size_t");
    array_push(cp_type_names, "ssize_t");
    array_push(cp_type_names, "ptrdiff_t");
    array_push(cp_type_names, "intptr_t");
    array_push(cp_type_names, "uintptr_t");
    array_push(cp_type_names, "int8_t");
    array_push(cp_type_names, "int16_t");
    array_push(cp_type_names, "int32_t");
    array_push(cp_type_names, "int64_t");
    array_push(cp_type_names, "uint8_t");
    array_push(cp_type_names, "uint16_t");
    array_push(cp_type_names, "uint32_t");
    array_push(cp_type_names, "uint64_t");
    array_push(cp_type_names, "bool");
    array_push(cp_type_names, "FILE");
    array_push(cp_type_names, "NULL");
    return 0;
}

fn cp_add_type_name(name: string) -> i32 {
    // Check if already registered
    var i: i32 = 0;
    while i < array_len(cp_type_names) {
        if str_eq(array_get(cp_type_names, i), name) { return 0; }
        i = i + 1;
    }
    array_push(cp_type_names, name);
    return 0;
}

fn cp_is_type_name(name: string) -> bool {
    var i: i32 = 0;
    while i < array_len(cp_type_names) {
        if str_eq(array_get(cp_type_names, i), name) { return true; }
        i = i + 1;
    }
    return false;
}

// ── Token Navigation ────────────────────────────────

fn cp_at_end() -> bool {
    return cp_pos >= c_tok_count;
}

fn cp_peek() -> i32 {
    if cp_pos >= c_tok_count { return CTK_EOF(); }
    return array_get(c_tok_types, cp_pos);
}

fn cp_peek_val() -> string {
    if cp_pos >= c_tok_count { return ""; }
    return array_get(c_tok_vals, cp_pos);
}

fn cp_peek_at(offset: i32) -> i32 {
    let p: i32 = cp_pos + offset;
    if p >= c_tok_count { return CTK_EOF(); }
    return array_get(c_tok_types, p);
}

fn cp_peek_val_at(offset: i32) -> string {
    let p: i32 = cp_pos + offset;
    if p >= c_tok_count { return ""; }
    return array_get(c_tok_vals, p);
}

fn cp_advance() -> string {
    let val: string = cp_peek_val();
    if cp_pos < c_tok_count { cp_pos = cp_pos + 1; }
    return val;
}

fn cp_match_type(t: i32) -> bool {
    if cp_peek() == t { cp_advance(); return true; }
    return false;
}

fn cp_match_val(v: string) -> bool {
    if str_eq(cp_peek_val(), v) { cp_advance(); return true; }
    return false;
}

fn cp_expect_val(v: string) -> i32 {
    if str_eq(cp_peek_val(), v) { cp_advance(); return 1; }
    return 0;
}

// ── Skip Helpers ────────────────────────────────────

// Skip balanced braces { ... }, assumes current token is {
fn cp_skip_braces() -> i32 {
    var depth: i32 = 0;
    if str_eq(cp_peek_val(), "{") { depth = 1; cp_advance(); }
    while !cp_at_end() && depth > 0 {
        let v: string = cp_advance();
        if str_eq(v, "{") { depth = depth + 1; }
        if str_eq(v, "}") { depth = depth - 1; }
    }
    return 0;
}

// Skip balanced parentheses ( ... ), assumes current token is (
fn cp_skip_parens() -> i32 {
    var depth: i32 = 0;
    if str_eq(cp_peek_val(), "(") { depth = 1; cp_advance(); }
    while !cp_at_end() && depth > 0 {
        let v: string = cp_advance();
        if str_eq(v, "(") { depth = depth + 1; }
        if str_eq(v, ")") { depth = depth - 1; }
    }
    return 0;
}

// Skip to next semicolon at depth 0
fn cp_skip_to_semi() -> i32 {
    var depth: i32 = 0;
    while !cp_at_end() {
        let v: string = cp_peek_val();
        if str_eq(v, "{") || str_eq(v, "(") || str_eq(v, "[") { depth = depth + 1; }
        if str_eq(v, "}") || str_eq(v, ")") || str_eq(v, "]") { depth = depth - 1; }
        if str_eq(v, ";") && depth == 0 { cp_advance(); return 0; }
        cp_advance();
    }
    return 0;
}

// ── Type Parsing ────────────────────────────────────
// Collects type specifiers into a string: "static const unsigned long long *"

fn cp_is_storage_class(v: string) -> bool {
    return str_eq(v, "static") || str_eq(v, "extern") || str_eq(v, "inline") ||
           str_eq(v, "register") || str_eq(v, "auto") || str_eq(v, "_Thread_local");
}

fn cp_is_type_qualifier(v: string) -> bool {
    return str_eq(v, "const") || str_eq(v, "volatile") || str_eq(v, "restrict") ||
           str_eq(v, "_Atomic");
}

fn cp_is_type_specifier(v: string) -> bool {
    return str_eq(v, "void") || str_eq(v, "char") || str_eq(v, "short") ||
           str_eq(v, "int") || str_eq(v, "long") || str_eq(v, "float") ||
           str_eq(v, "double") || str_eq(v, "signed") || str_eq(v, "unsigned") ||
           str_eq(v, "bool") || str_eq(v, "_Bool") ||
           str_eq(v, "struct") || str_eq(v, "union") || str_eq(v, "enum");
}

fn cp_is_type_start() -> bool {
    let v: string = cp_peek_val();
    if cp_is_storage_class(v) { return true; }
    if cp_is_type_qualifier(v) { return true; }
    if cp_is_type_specifier(v) { return true; }
    if cp_peek() == CTK_IDENT() && cp_is_type_name(v) { return true; }
    return false;
}

// Parse type specifiers, return as string. Stops before declarator.
// Examples: "int", "const char", "unsigned long long", "struct foo", "static int"
fn cp_parse_base_type() -> string {
    var result: string = "";
    var storage: string = "";

    // Collect storage class
    while cp_is_storage_class(cp_peek_val()) {
        if len(storage) > 0 { storage = cc(storage, " "); }
        storage = cc(storage, cp_advance());
    }

    // Collect qualifiers and type specifiers
    var got_type: bool = false;
    while !cp_at_end() {
        let v: string = cp_peek_val();

        if cp_is_type_qualifier(v) {
            if len(result) > 0 { result = cc(result, " "); }
            result = cc(result, cp_advance());
        } else if cp_is_type_specifier(v) {
            if len(result) > 0 { result = cc(result, " "); }
            // Handle struct/union/enum + name
            if str_eq(v, "struct") || str_eq(v, "union") || str_eq(v, "enum") {
                result = cc(result, cp_advance());
                if cp_peek() == CTK_IDENT() {
                    result = cc(result, cc(" ", cp_advance()));
                }
            } else {
                result = cc(result, cp_advance());
            }
            got_type = true;
        } else if cp_peek() == CTK_IDENT() && cp_is_type_name(v) && !got_type {
            if len(result) > 0 { result = cc(result, " "); }
            result = cc(result, cp_advance());
            got_type = true;
        } else {
            // Not a type token, stop
            if !got_type && cp_peek() == CTK_IDENT() {
                // Unknown identifier might be a typedef'd type
                // Heuristic: if followed by * or identifier, treat as type
                let next: i32 = cp_peek_at(1);
                let next_v: string = cp_peek_val_at(1);
                if str_eq(next_v, "*") || next == CTK_IDENT() {
                    if len(result) > 0 { result = cc(result, " "); }
                    let tn: string = cp_advance();
                    cp_add_type_name(tn);
                    result = cc(result, tn);
                    got_type = true;
                } else {
                    // Give up
                    if len(result) == 0 { result = "int"; }
                    if len(storage) > 0 { return cc(storage, cc(" ", result)); }
                    return result;
                }
            } else {
                if len(result) == 0 { result = "int"; }
                if len(storage) > 0 { return cc(storage, cc(" ", result)); }
                return result;
            }
        }
    }

    if len(result) == 0 { result = "int"; }
    if len(storage) > 0 { return cc(storage, cc(" ", result)); }
    return result;
}

// Collect pointer stars after base type
fn cp_parse_pointers() -> string {
    var ptrs: string = "";
    while str_eq(cp_peek_val(), "*") {
        ptrs = cc(ptrs, "*");
        cp_advance();
        // Collect const/volatile after *
        while cp_is_type_qualifier(cp_peek_val()) {
            ptrs = cc(ptrs, cc(" ", cp_advance()));
        }
    }
    return ptrs;
}

// ── Parameter Parsing ───────────────────────────────

// Parse a single function parameter, return node index
fn cp_parse_param() -> i32 {
    // Handle ... (variadic)
    if str_eq(cp_peek_val(), ".") {
        cp_advance();
        if str_eq(cp_peek_val(), ".") { cp_advance(); }
        if str_eq(cp_peek_val(), ".") { cp_advance(); }
        return cn_new(CNK_PARAM(), "...", "...", 0, 0, 0);
    }

    // Handle void parameter (just "void" with no name)
    if str_eq(cp_peek_val(), "void") {
        let save: i32 = cp_pos;
        cp_advance();
        if str_eq(cp_peek_val(), ")") || str_eq(cp_peek_val(), ",") {
            return cn_new(CNK_PARAM(), "", "void", 0, 0, 0);
        }
        cp_pos = save;
    }

    let base: string = cp_parse_base_type();
    let ptrs: string = cp_parse_pointers();
    var full_type: string = base;
    if len(ptrs) > 0 { full_type = cc(base, cc(" ", ptrs)); }

    // Parse declarator name (might be absent in declarations)
    var name: string = "";
    if cp_peek() == CTK_IDENT() {
        name = cp_advance();
    }

    // Handle array declarator: name[size]
    if str_eq(cp_peek_val(), "[") {
        cp_advance();
        while !cp_at_end() && !str_eq(cp_peek_val(), "]") { cp_advance(); }
        cp_match_val("]");
        full_type = cc(full_type, "[]");
    }

    // Handle function pointer: (*name)(params)
    // Already partially consumed, just skip
    if str_eq(cp_peek_val(), "(") {
        cp_skip_parens();
        full_type = cc(full_type, "(*)()");
    }

    return cn_new(CNK_PARAM(), name, full_type, 0, 0, 0);
}

// Parse parameter list (assumes '(' already consumed)
// Returns: temp array of param node indices
fn cp_parse_params() -> i32 {
    let params: i32 = array_new(0);

    if str_eq(cp_peek_val(), ")") { cp_advance(); return params; }

    array_push(params, cp_parse_param());
    while str_eq(cp_peek_val(), ",") {
        cp_advance();
        array_push(params, cp_parse_param());
    }

    cp_expect_val(")");
    return params;
}

// ── Struct Field Parsing ────────────────────────────

fn cp_parse_struct_fields() -> i32 {
    let fields: i32 = array_new(0);

    while !cp_at_end() && !str_eq(cp_peek_val(), "}") {
        // Skip preprocessor inside struct
        if cp_peek() == CTK_PREPROC() {
            cp_advance();
        }
        // Nested struct/union/enum with body
        else if str_eq(cp_peek_val(), "struct") || str_eq(cp_peek_val(), "union") || str_eq(cp_peek_val(), "enum") {
            let nested_kw: string = cp_advance();
            var nested_name: string = "";
            if cp_peek() == CTK_IDENT() { nested_name = cp_advance(); }
            if str_eq(cp_peek_val(), "{") {
                cp_skip_braces();
                // Optional field name after closing brace
                var fname: string = "";
                if cp_peek() == CTK_IDENT() { fname = cp_advance(); }
                var ntype: string = nested_kw;
                if len(nested_name) > 0 {
                    ntype = str_concat(nested_kw, str_concat(" ", nested_name));
                }
                array_push(fields, cn_new(CNK_FIELD(), fname, ntype, 0, 0, 0));
            }
            cp_match_val(";");
        }
        else if str_eq(cp_peek_val(), "}") {
            // end of struct
        }
        else {
            let save_pos: i32 = cp_pos;
            let base: string = cp_parse_base_type();
            // Parse one or more declarators
            var first: bool = true;
            while !cp_at_end() && !str_eq(cp_peek_val(), ";") && !str_eq(cp_peek_val(), "}") {
                if !first { cp_expect_val(","); }
                first = false;

                let ptrs: string = cp_parse_pointers();
                var full_type: string = base;
                if len(ptrs) > 0 { full_type = cc(base, cc(" ", ptrs)); }

                var name: string = "";
                if cp_peek() == CTK_IDENT() { name = cp_advance(); }

                // Function pointer field: (*name)(params)
                if str_eq(cp_peek_val(), "(") && len(name) == 0 {
                    cp_skip_parens();
                    name = "(*)";
                    if str_eq(cp_peek_val(), "(") { cp_skip_parens(); }
                }

                // Array field: name[size]
                if str_eq(cp_peek_val(), "[") {
                    cp_advance();
                    var arr_size: string = "";
                    while !cp_at_end() && !str_eq(cp_peek_val(), "]") {
                        arr_size = cc(arr_size, cp_advance());
                    }
                    cp_expect_val("]");
                    full_type = cc(full_type, cc("[", cc(arr_size, "]")));
                }

                // Bitfield: name : width
                if str_eq(cp_peek_val(), ":") {
                    cp_advance();
                    if cp_peek() == CTK_INT_LIT() {
                        full_type = cc(full_type, cc(":", cp_advance()));
                    }
                }

                array_push(fields, cn_new(CNK_FIELD(), name, full_type, 0, 0, 0));

                // Safety: if we didn't advance, force advance to prevent infinite loop
                if cp_pos == save_pos {
                    cp_advance();
                    save_pos = cp_pos;
                }
            }
            cp_match_val(";");
        }
    }

    return fields;
}

// ── Enum Constant Parsing ───────────────────────────

fn cp_parse_enum_consts() -> i32 {
    let consts: i32 = array_new(0);

    while !cp_at_end() && !str_eq(cp_peek_val(), "}") {
        if cp_peek() == CTK_IDENT() {
            let name: string = cp_advance();
            var val: string = "";
            if str_eq(cp_peek_val(), "=") {
                cp_advance();
                // Collect value expression until , or } at depth 0
                var depth: i32 = 0;
                var done: bool = false;
                while !cp_at_end() && !done {
                    let v: string = cp_peek_val();
                    if (str_eq(v, ",") || str_eq(v, "}")) && depth == 0 {
                        done = true;
                    }
                    if !done {
                        if str_eq(v, "(") { depth = depth + 1; }
                        if str_eq(v, ")") { depth = depth - 1; }
                        if len(val) > 0 { val = cc(val, " "); }
                        val = cc(val, cp_advance());
                    }
                }
            }
            array_push(consts, cn_new(CNK_ENUM_CONST(), name, val, 0, 0, 0));
            cp_match_val(",");
        } else {
            cp_advance(); // skip unexpected token
        }
    }

    return consts;
}

// ── Top-Level Parsing ───────────────────────────────

fn cp_parse_struct_or_union() -> i32 {
    let keyword: string = cp_advance(); // "struct" or "union"
    var name: string = "";
    if cp_peek() == CTK_IDENT() { name = cp_advance(); }

    if str_eq(cp_peek_val(), "{") {
        cp_advance(); // consume {
        let fields: i32 = cp_parse_struct_fields();
        cp_expect_val("}");

        let fstart: i32 = cn_flush(fields);
        let fcount: i32 = array_len(fields);

        // Register struct name as type
        if len(name) > 0 { cp_add_type_name(name); }

        // Check for variable declarations after struct def
        // struct foo { ... } var1, var2;
        if str_eq(cp_peek_val(), ";") {
            cp_advance();
            return cn_new(CNK_STRUCT_DEF(), name, keyword, fstart, fcount, 0);
        }

        // Variable declared with struct type
        let struct_node: i32 = cn_new(CNK_STRUCT_DEF(), name, keyword, fstart, fcount, 0);
        cp_skip_to_semi();
        return struct_node;
    }

    // Forward declaration: struct foo;
    // Or used as type: struct foo *ptr;
    return 0 - 1; // signal: this is a type, not a complete declaration
}

fn cp_parse_enum() -> i32 {
    cp_advance(); // consume "enum"
    var name: string = "";
    if cp_peek() == CTK_IDENT() { name = cp_advance(); }

    if str_eq(cp_peek_val(), "{") {
        cp_advance();
        let consts: i32 = cp_parse_enum_consts();
        cp_expect_val("}");

        let cstart: i32 = cn_flush(consts);
        let ccount: i32 = array_len(consts);

        if len(name) > 0 { cp_add_type_name(name); }

        cp_match_val(";");
        return cn_new(CNK_ENUM_DEF(), name, "enum", cstart, ccount, 0);
    }

    return 0 - 1;
}

fn cp_parse_typedef() -> i32 {
    cp_advance(); // consume "typedef"

    // typedef struct { ... } Name;
    // typedef enum { ... } Name;
    // typedef int (*FuncPtr)(int, int);
    // typedef unsigned long size_t;

    if str_eq(cp_peek_val(), "struct") || str_eq(cp_peek_val(), "union") {
        let keyword: string = cp_advance();
        var tag: string = "";
        if cp_peek() == CTK_IDENT() && str_eq(cp_peek_val_at(1), "{") {
            tag = cp_advance();
        } else if cp_peek() == CTK_IDENT() && !str_eq(cp_peek_val_at(1), "{") {
            // typedef struct Foo Foo;
            tag = cp_advance();
            var alias: string = "";
            if cp_peek() == CTK_IDENT() { alias = cp_advance(); }
            cp_match_val(";");
            if len(alias) > 0 { cp_add_type_name(alias); }
            return cn_new(CNK_TYPEDEF(), alias, cc(keyword, cc(" ", tag)), 0, 0, 0);
        }

        if str_eq(cp_peek_val(), "{") {
            cp_advance();
            let fields: i32 = cp_parse_struct_fields();
            cp_expect_val("}");
            let fstart: i32 = cn_flush(fields);
            let fcount: i32 = array_len(fields);

            // The name after } is the typedef name
            var alias2: string = "";
            let ptrs: string = cp_parse_pointers();
            if cp_peek() == CTK_IDENT() { alias2 = cp_advance(); }
            cp_match_val(";");

            if len(alias2) > 0 { cp_add_type_name(alias2); }
            if len(tag) > 0 { cp_add_type_name(tag); }

            // Create struct definition node
            let snode: i32 = cn_new(CNK_STRUCT_DEF(), tag, keyword, fstart, fcount, 0);
            return cn_new(CNK_TYPEDEF(), alias2, cc(keyword, cc(" ", tag)), snode, 0, 0);
        }
        cp_skip_to_semi();
        return cn_new(CNK_TYPEDEF(), "", keyword, 0, 0, 0);
    }

    if str_eq(cp_peek_val(), "enum") {
        cp_advance();
        var etag: string = "";
        if cp_peek() == CTK_IDENT() && str_eq(cp_peek_val_at(1), "{") {
            etag = cp_advance();
        }
        if str_eq(cp_peek_val(), "{") {
            cp_advance();
            let consts: i32 = cp_parse_enum_consts();
            cp_expect_val("}");
            let cstart: i32 = cn_flush(consts);
            let ccount: i32 = array_len(consts);

            var ealias: string = "";
            if cp_peek() == CTK_IDENT() { ealias = cp_advance(); }
            cp_match_val(";");

            if len(ealias) > 0 { cp_add_type_name(ealias); }
            let enode: i32 = cn_new(CNK_ENUM_DEF(), etag, "enum", cstart, ccount, 0);
            return cn_new(CNK_TYPEDEF(), ealias, "enum", enode, 0, 0);
        }
        cp_skip_to_semi();
        return cn_new(CNK_TYPEDEF(), "", "enum", 0, 0, 0);
    }

    // Simple typedef: typedef <type> <name>;
    // Or function pointer: typedef <ret> (*<name>)(<params>);
    let base: string = cp_parse_base_type();
    let ptrs2: string = cp_parse_pointers();
    var orig_type: string = base;
    if len(ptrs2) > 0 { orig_type = cc(base, cc(" ", ptrs2)); }

    // Function pointer typedef: typedef int (*name)(int, int);
    if str_eq(cp_peek_val(), "(") && str_eq(cp_peek_val_at(1), "*") {
        cp_advance(); // (
        cp_advance(); // *
        var fp_name: string = "";
        if cp_peek() == CTK_IDENT() { fp_name = cp_advance(); }
        cp_expect_val(")");
        // Skip parameter list
        if str_eq(cp_peek_val(), "(") { cp_skip_parens(); }
        cp_match_val(";");
        if len(fp_name) > 0 { cp_add_type_name(fp_name); }
        return cn_new(CNK_TYPEDEF(), fp_name, cc(orig_type, " (*)()"), 0, 0, 0);
    }

    var alias3: string = "";
    if cp_peek() == CTK_IDENT() { alias3 = cp_advance(); }

    // Array typedef: typedef int Arr[10];
    if str_eq(cp_peek_val(), "[") {
        cp_advance();
        var arr_sz: string = "";
        while !cp_at_end() && !str_eq(cp_peek_val(), "]") {
            arr_sz = cc(arr_sz, cp_advance());
        }
        cp_expect_val("]");
        orig_type = cc(orig_type, cc("[", cc(arr_sz, "]")));
    }

    cp_match_val(";");
    if len(alias3) > 0 { cp_add_type_name(alias3); }
    return cn_new(CNK_TYPEDEF(), alias3, orig_type, 0, 0, 0);
}

// Parse a top-level declaration (function or global variable)
// Assumes type specifiers haven't been consumed yet
fn cp_parse_declaration() -> i32 {
    let base: string = cp_parse_base_type();
    let ptrs: string = cp_parse_pointers();
    var full_type: string = base;
    if len(ptrs) > 0 { full_type = cc(base, cc(" ", ptrs)); }

    // Function pointer declaration: type (*name)(params) = ...;
    if str_eq(cp_peek_val(), "(") && str_eq(cp_peek_val_at(1), "*") {
        cp_skip_to_semi();
        return cn_new(CNK_GLOBAL_VAR(), "", full_type, 0, 0, 0);
    }

    // Get declarator name
    var name: string = "";
    if cp_peek() == CTK_IDENT() { name = cp_advance(); }

    if len(name) == 0 {
        // No name found, skip to semicolon
        cp_skip_to_semi();
        return cn_new(CNK_GLOBAL_VAR(), "", full_type, 0, 0, 0);
    }

    // Function definition or declaration
    if str_eq(cp_peek_val(), "(") {
        cp_advance(); // consume (
        let params: i32 = cp_parse_params();
        let pstart: i32 = cn_flush(params);
        let pcount: i32 = array_len(params);

        // Possible attributes after params: __attribute__((...))
        while str_eq(cp_peek_val(), "__attribute__") {
            cp_advance();
            if str_eq(cp_peek_val(), "(") { cp_skip_parens(); }
        }

        if str_eq(cp_peek_val(), "{") {
            // Function definition — skip body
            cp_skip_braces();
            return cn_new(CNK_FUNC_DEF(), name, full_type, pstart, pcount, 0);
        }

        // Function declaration
        cp_match_val(";");
        return cn_new(CNK_FUNC_DECL(), name, full_type, pstart, pcount, 0);
    }

    // Array variable: type name[size] = ...;
    if str_eq(cp_peek_val(), "[") {
        cp_advance();
        var arr_sz2: string = "";
        while !cp_at_end() && !str_eq(cp_peek_val(), "]") {
            arr_sz2 = cc(arr_sz2, cp_advance());
        }
        cp_expect_val("]");
        full_type = cc(full_type, cc("[", cc(arr_sz2, "]")));
    }

    // Variable with initializer
    if str_eq(cp_peek_val(), "=") {
        cp_advance();
        // Skip initializer (might contain braces for struct/array init)
        if str_eq(cp_peek_val(), "{") {
            cp_skip_braces();
        } else {
            // Skip expression until ;
            var depth: i32 = 0;
            while !cp_at_end() {
                let v: string = cp_peek_val();
                if str_eq(v, "(") || str_eq(v, "[") { depth = depth + 1; }
                if str_eq(v, ")") || str_eq(v, "]") { depth = depth - 1; }
                if str_eq(v, ";") && depth <= 0 { cp_advance(); return cn_new(CNK_GLOBAL_VAR(), name, full_type, 0, 0, 0); }
                cp_advance();
            }
        }
    }

    // Multiple declarators: int a, b, *c;
    while str_eq(cp_peek_val(), ",") {
        cp_advance();
        // Skip additional declarators
        while !cp_at_end() && !str_eq(cp_peek_val(), ",") && !str_eq(cp_peek_val(), ";") {
            if str_eq(cp_peek_val(), "=") {
                cp_advance();
                if str_eq(cp_peek_val(), "{") { cp_skip_braces(); }
            } else {
                cp_advance();
            }
        }
    }

    cp_match_val(";");
    return cn_new(CNK_GLOBAL_VAR(), name, full_type, 0, 0, 0);
}

// ── Main Program Parser ─────────────────────────────

fn cp_parse_program() -> i32 {
    let decls: i32 = array_new(0);

    while !cp_at_end() && cp_peek() != CTK_EOF() {
        let loop_save: i32 = cp_pos;

        // Preprocessor directive
        if cp_peek() == CTK_PREPROC() {
            let pval: string = cp_peek_val();
            cp_advance();
            array_push(decls, cn_new(CNK_PREPROC(), pval, "", 0, 0, 0));
        }
        // typedef
        else if str_eq(cp_peek_val(), "typedef") {
            let td: i32 = cp_parse_typedef();
            if td >= 0 { array_push(decls, td); }
        }
        // struct/union at top level
        else if str_eq(cp_peek_val(), "struct") || str_eq(cp_peek_val(), "union") {
            // Could be: struct definition, or type used in declaration
            // Peek ahead to decide
            let save: i32 = cp_pos;
            let kw: string = cp_peek_val();
            cp_advance(); // skip struct/union

            var tag_name: string = "";
            if cp_peek() == CTK_IDENT() { tag_name = cp_peek_val(); }

            // struct name { ... }
            if cp_peek() == CTK_IDENT() && str_eq(cp_peek_val_at(1), "{") {
                cp_pos = save;
                let sn: i32 = cp_parse_struct_or_union();
                if sn >= 0 { array_push(decls, sn); }
            }
            // struct { ... } (anonymous)
            else if str_eq(cp_peek_val(), "{") {
                cp_pos = save;
                let sn2: i32 = cp_parse_struct_or_union();
                if sn2 >= 0 { array_push(decls, sn2); }
            }
            // struct name *func(...) or struct name var;
            else {
                cp_pos = save;
                let decl: i32 = cp_parse_declaration();
                if decl >= 0 { array_push(decls, decl); }
            }
        }
        // enum at top level
        else if str_eq(cp_peek_val(), "enum") {
            let save2: i32 = cp_pos;
            cp_advance();
            // enum name { ... } or enum { ... }
            if str_eq(cp_peek_val(), "{") || (cp_peek() == CTK_IDENT() && str_eq(cp_peek_val_at(1), "{")) {
                cp_pos = save2;
                let en: i32 = cp_parse_enum();
                if en >= 0 { array_push(decls, en); }
            } else {
                // enum used as type in declaration
                cp_pos = save2;
                let decl2: i32 = cp_parse_declaration();
                if decl2 >= 0 { array_push(decls, decl2); }
            }
        }
        // Semicolons (empty statements)
        else if str_eq(cp_peek_val(), ";") {
            cp_advance();
        }
        // Regular declaration (function or variable)
        else if cp_is_type_start() {
            let decl3: i32 = cp_parse_declaration();
            if decl3 >= 0 { array_push(decls, decl3); }
        }
        // Unknown token — skip
        else {
            cp_advance();
        }

        // Safety: if no progress was made, force advance to prevent infinite loop
        if cp_pos == loop_save { cp_advance(); }
    }

    let dstart: i32 = cn_flush(decls);
    let dcount: i32 = array_len(decls);
    return cn_new(CNK_PROGRAM(), "", "", dstart, dcount, 0);
}

// ── Analysis Functions ──────────────────────────────

fn cp_count_by_kind(kind: i32, prog: i32) -> i32 {
    var count: i32 = 0;
    let start: i32 = cnd1(prog);
    let total: i32 = cnd2(prog);
    var i: i32 = 0;
    while i < total {
        if cnk(cn_child(start, i)) == kind { count = count + 1; }
        i = i + 1;
    }
    return count;
}

fn cp_count_functions(prog: i32) -> i32 {
    return cp_count_by_kind(CNK_FUNC_DEF(), prog);
}

fn cp_count_func_decls(prog: i32) -> i32 {
    return cp_count_by_kind(CNK_FUNC_DECL(), prog);
}

fn cp_count_structs(prog: i32) -> i32 {
    return cp_count_by_kind(CNK_STRUCT_DEF(), prog);
}

fn cp_count_enums(prog: i32) -> i32 {
    return cp_count_by_kind(CNK_ENUM_DEF(), prog);
}

fn cp_count_typedefs(prog: i32) -> i32 {
    return cp_count_by_kind(CNK_TYPEDEF(), prog);
}

fn cp_count_globals(prog: i32) -> i32 {
    return cp_count_by_kind(CNK_GLOBAL_VAR(), prog);
}

fn cp_count_preprocs(prog: i32) -> i32 {
    return cp_count_by_kind(CNK_PREPROC(), prog);
}

// Print function signature
fn cp_print_func(node: i32) -> i32 {
    let ret: string = cnt(node);
    let name: string = cnn(node);
    let pstart: i32 = cnd1(node);
    let pcount: i32 = cnd2(node);

    print(ret);
    print(" ");
    print(name);
    print("(");
    var i: i32 = 0;
    while i < pcount {
        if i > 0 { print(", "); }
        let p: i32 = cn_child(pstart, i);
        print(cnt(p));
        if len(cnn(p)) > 0 {
            print(" ");
            print(cnn(p));
        }
        i = i + 1;
    }
    println(")");
    return 0;
}

// Print struct definition
fn cp_print_struct(node: i32) -> i32 {
    let name: string = cnn(node);
    let kw: string = cnt(node);
    let fstart: i32 = cnd1(node);
    let fcount: i32 = cnd2(node);

    print(kw);
    print(" ");
    print(name);
    println(" {");
    var i: i32 = 0;
    while i < fcount {
        let f: i32 = cn_child(fstart, i);
        print("    ");
        print(cnt(f));
        if len(cnn(f)) > 0 {
            print(" ");
            print(cnn(f));
        }
        println(";");
        i = i + 1;
    }
    println("}");
    return 0;
}

// Full analysis report
fn cp_report(prog: i32) -> i32 {
    let total: i32 = cnd2(prog);
    println("=== C Parser Analysis ===");
    print("  Total declarations: ");
    println(int_to_str(total));
    print("  Functions: ");
    println(int_to_str(cp_count_functions(prog)));
    print("  Function declarations: ");
    println(int_to_str(cp_count_func_decls(prog)));
    print("  Structs: ");
    println(int_to_str(cp_count_structs(prog)));
    print("  Enums: ");
    println(int_to_str(cp_count_enums(prog)));
    print("  Typedefs: ");
    println(int_to_str(cp_count_typedefs(prog)));
    print("  Global variables: ");
    println(int_to_str(cp_count_globals(prog)));
    print("  Preprocessor: ");
    println(int_to_str(cp_count_preprocs(prog)));

    // List functions
    let nfuncs: i32 = cp_count_functions(prog);
    if nfuncs > 0 {
        println("");
        println("--- Functions ---");
        let start: i32 = cnd1(prog);
        var i: i32 = 0;
        while i < total {
            let node: i32 = cn_child(start, i);
            if cnk(node) == CNK_FUNC_DEF() {
                print("  ");
                cp_print_func(node);
            }
            i = i + 1;
        }
    }

    // List structs
    let nstructs: i32 = cp_count_structs(prog);
    if nstructs > 0 {
        println("");
        println("--- Structs ---");
        let start2: i32 = cnd1(prog);
        var i2: i32 = 0;
        while i2 < total {
            let node2: i32 = cn_child(start2, i2);
            if cnk(node2) == CNK_STRUCT_DEF() {
                cp_print_struct(node2);
            }
            i2 = i2 + 1;
        }
    }

    return 0;
}

// ── Parse helper: tokenize + parse ──────────────────

fn cp_parse(src: string) -> i32 {
    c_tokenize(src);
    cp_init();
    cp_init_ast();
    return cp_parse_program();
}

fn cp_parse_file(path: string) -> i32 {
    let src: string = read_file(path);
    if len(src) == 0 {
        println("Error: cannot read file");
        return 0 - 1;
    }
    return cp_parse(src);
}

// ── Tests ───────────────────────────────────────────

fn test_c_parser() -> i32 {
    var tests_run: i32 = 0;
    var tests_passed: i32 = 0;
    println("=== C Parser Tests ===");

    // Test 1: empty input
    tests_run = tests_run + 1;
    let t1: i32 = cp_parse("");
    if cnd2(t1) == 0 {
        tests_passed = tests_passed + 1;
        println("  OK  empty input");
    } else { println("  FAIL empty input"); }

    // Test 2: simple function
    tests_run = tests_run + 1;
    let t2: i32 = cp_parse("int main() { return 0; }");
    if cp_count_functions(t2) == 1 && str_eq(cnn(cn_child(cnd1(t2), 0)), "main") {
        tests_passed = tests_passed + 1;
        println("  OK  simple function");
    } else {
        print("  FAIL simple function (funcs=");
        print(int_to_str(cp_count_functions(t2)));
        println(")");
    }

    // Test 3: function with params
    tests_run = tests_run + 1;
    let t3: i32 = cp_parse("static char *read_file(const char *path) { return 0; }");
    if cp_count_functions(t3) == 1 {
        let f3: i32 = cn_child(cnd1(t3), 0);
        if str_eq(cnn(f3), "read_file") && cnd2(f3) == 1 {
            tests_passed = tests_passed + 1;
            println("  OK  function with params");
        } else {
            print("  FAIL function with params (name=");
            print(cnn(f3));
            print(", params=");
            print(int_to_str(cnd2(f3)));
            println(")");
        }
    } else {
        print("  FAIL function with params (funcs=");
        print(int_to_str(cp_count_functions(t3)));
        println(")");
    }

    // Test 4: struct definition
    tests_run = tests_run + 1;
    let t4: i32 = cp_parse("struct Point { int x; int y; };");
    if cp_count_structs(t4) == 1 {
        let s4: i32 = cn_child(cnd1(t4), 0);
        if str_eq(cnn(s4), "Point") && cnd2(s4) == 2 {
            tests_passed = tests_passed + 1;
            println("  OK  struct definition");
        } else {
            print("  FAIL struct definition (name=");
            print(cnn(s4));
            print(", fields=");
            print(int_to_str(cnd2(s4)));
            println(")");
        }
    } else {
        print("  FAIL struct definition (structs=");
        print(int_to_str(cp_count_structs(t4)));
        println(")");
    }

    // Test 5: typedef struct
    tests_run = tests_run + 1;
    let t5: i32 = cp_parse("typedef struct { int kind; const char *name; } TypeNode;");
    if cp_count_typedefs(t5) == 1 {
        let td5: i32 = cn_child(cnd1(t5), 0);
        if str_eq(cnn(td5), "TypeNode") {
            tests_passed = tests_passed + 1;
            println("  OK  typedef struct");
        } else {
            print("  FAIL typedef struct (name=");
            print(cnn(td5));
            println(")");
        }
    } else {
        print("  FAIL typedef struct (typedefs=");
        print(int_to_str(cp_count_typedefs(t5)));
        println(")");
    }

    // Test 6: typedef enum
    tests_run = tests_run + 1;
    let t6: i32 = cp_parse("typedef enum { TYPE_INT, TYPE_FLOAT, TYPE_VOID } TypeKind;");
    if cp_count_typedefs(t6) == 1 {
        let td6: i32 = cn_child(cnd1(t6), 0);
        if str_eq(cnn(td6), "TypeKind") {
            tests_passed = tests_passed + 1;
            println("  OK  typedef enum");
        } else {
            print("  FAIL typedef enum (name=");
            print(cnn(td6));
            println(")");
        }
    } else {
        print("  FAIL typedef enum (typedefs=");
        print(int_to_str(cp_count_typedefs(t6)));
        println(")");
    }

    // Test 7: global variable
    tests_run = tests_run + 1;
    let t7: i32 = cp_parse("static int count = 0;");
    if cp_count_globals(t7) == 1 {
        let g7: i32 = cn_child(cnd1(t7), 0);
        if str_eq(cnn(g7), "count") {
            tests_passed = tests_passed + 1;
            println("  OK  global variable");
        } else {
            print("  FAIL global variable (name=");
            print(cnn(g7));
            println(")");
        }
    } else {
        print("  FAIL global variable (globals=");
        print(int_to_str(cp_count_globals(t7)));
        println(")");
    }

    // Test 8: multiple functions
    tests_run = tests_run + 1;
    let t8: i32 = cp_parse("int add(int a, int b) { return a + b; } int sub(int a, int b) { return a - b; } int main() { return 0; }");
    if cp_count_functions(t8) == 3 {
        tests_passed = tests_passed + 1;
        println("  OK  multiple functions");
    } else {
        print("  FAIL multiple functions (funcs=");
        print(int_to_str(cp_count_functions(t8)));
        println(")");
    }

    // Test 9: function declaration (no body)
    tests_run = tests_run + 1;
    let t9: i32 = cp_parse("int printf(const char *fmt, ...);");
    if cp_count_func_decls(t9) == 1 {
        let fd9: i32 = cn_child(cnd1(t9), 0);
        if str_eq(cnn(fd9), "printf") && cnd2(fd9) == 2 {
            tests_passed = tests_passed + 1;
            println("  OK  function declaration");
        } else {
            print("  FAIL function declaration (name=");
            print(cnn(fd9));
            print(", params=");
            print(int_to_str(cnd2(fd9)));
            println(")");
        }
    } else {
        print("  FAIL function declaration (decls=");
        print(int_to_str(cp_count_func_decls(t9)));
        println(")");
    }

    // Test 10: preprocessor directives
    tests_run = tests_run + 1;
    let pp_src: string = "#include <stdio.h>";
    let t10: i32 = cp_parse(pp_src);
    if cp_count_preprocs(t10) == 1 {
        tests_passed = tests_passed + 1;
        println("  OK  preprocessor");
    } else {
        print("  FAIL preprocessor (preprocs=");
        print(int_to_str(cp_count_preprocs(t10)));
        println(")");
    }

    // Test 11: parse mc.c (real file)
    tests_run = tests_run + 1;
    let t11: i32 = cp_parse_file("m/bootstrap/mc.c");
    if t11 >= 0 {
        let mc_funcs: i32 = cp_count_functions(t11);
        if mc_funcs >= 3 {
            tests_passed = tests_passed + 1;
            print("  OK  mc.c (");
            print(int_to_str(mc_funcs));
            println(" functions)");
        } else {
            print("  FAIL mc.c (funcs=");
            print(int_to_str(mc_funcs));
            println(")");
        }
    } else { println("  FAIL mc.c (cannot read)"); }

    // Test 12: parse lexer.c
    tests_run = tests_run + 1;
    let t12: i32 = cp_parse_file("m/bootstrap/lexer.c");
    if t12 >= 0 {
        let lex_funcs: i32 = cp_count_functions(t12);
        if lex_funcs >= 5 {
            tests_passed = tests_passed + 1;
            print("  OK  lexer.c (");
            print(int_to_str(lex_funcs));
            println(" functions)");
        } else {
            print("  FAIL lexer.c (funcs=");
            print(int_to_str(lex_funcs));
            println(")");
        }
    } else { println("  FAIL lexer.c (cannot read)"); }

    // Test 13: parse parser.c
    tests_run = tests_run + 1;
    let t13: i32 = cp_parse_file("m/bootstrap/parser.c");
    if t13 >= 0 {
        let par_funcs: i32 = cp_count_functions(t13);
        let par_structs: i32 = cp_count_structs(t13);
        if par_funcs >= 10 {
            tests_passed = tests_passed + 1;
            print("  OK  parser.c (");
            print(int_to_str(par_funcs));
            print(" functions, ");
            print(int_to_str(par_structs));
            println(" structs)");
        } else {
            print("  FAIL parser.c (funcs=");
            print(int_to_str(par_funcs));
            println(")");
        }
    } else { println("  FAIL parser.c (cannot read)"); }

    // Test 14: parse ast.h (typedefs, enums, structs)
    tests_run = tests_run + 1;
    let t14: i32 = cp_parse_file("m/bootstrap/ast.h");
    if t14 >= 0 {
        let ast_typedefs: i32 = cp_count_typedefs(t14);
        let ast_structs: i32 = cp_count_structs(t14);
        if ast_typedefs >= 3 {
            tests_passed = tests_passed + 1;
            print("  OK  ast.h (");
            print(int_to_str(ast_typedefs));
            print(" typedefs, ");
            print(int_to_str(ast_structs));
            println(" structs)");
        } else {
            print("  FAIL ast.h (typedefs=");
            print(int_to_str(ast_typedefs));
            println(")");
        }
    } else { println("  FAIL ast.h (cannot read)"); }

    // Test 15: parse codegen.c (largest bootstrap file)
    tests_run = tests_run + 1;
    let t15: i32 = cp_parse_file("m/bootstrap/codegen.c");
    if t15 >= 0 {
        let cg_funcs: i32 = cp_count_functions(t15);
        let cg_globals: i32 = cp_count_globals(t15);
        if cg_funcs >= 10 {
            tests_passed = tests_passed + 1;
            print("  OK  codegen.c (");
            print(int_to_str(cg_funcs));
            print(" functions, ");
            print(int_to_str(cg_globals));
            println(" globals)");
        } else {
            print("  FAIL codegen.c (funcs=");
            print(int_to_str(cg_funcs));
            println(")");
        }
    } else { println("  FAIL codegen.c (cannot read)"); }

    // Test 16: parse vm.c
    tests_run = tests_run + 1;
    let t16: i32 = cp_parse_file("m/bootstrap/vm.c");
    if t16 >= 0 {
        let vm_funcs: i32 = cp_count_functions(t16);
        if vm_funcs >= 3 {
            tests_passed = tests_passed + 1;
            print("  OK  vm.c (");
            print(int_to_str(vm_funcs));
            println(" functions)");
        } else {
            print("  FAIL vm.c (funcs=");
            print(int_to_str(vm_funcs));
            println(")");
        }
    } else { println("  FAIL vm.c (cannot read)"); }

    println("");
    print(int_to_str(tests_passed));
    print("/");
    print(int_to_str(tests_run));
    println(" tests passed");

    if tests_passed == tests_run {
        println("");
        println("M reads C structure. Phase 2 deepens.");
    }

    return tests_passed == tests_run;
}

// ── Driver ──────────────────────────────────────────

fn main() -> i32 {
    if argc() >= 1 {
        // File analysis mode
        let path: string = argv(0);
        let prog: i32 = cp_parse_file(path);
        if prog >= 0 {
            cp_report(prog);
        }
        return 0;
    }

    // Test mode
    test_c_parser();
    return 0;
}
