// Machine REPL -Interactive Temporal Computing Shell
// A terminal where you experience Machine's temporal computation model.
//
// Usage:
//   mc.exe self_codegen.m machine_repl.m
//
// Commands:
//   bind <name> = <value>     -bind a name to a value (creates timeline)
//   bind <name> ~ <value>     -bind with uncertainty (approximate value)
//   load <name>               -load current value of a name
//   history <name>            -show full timeline of a name
//   forget <name>             -forget a binding (value persists in history)
//   snapshot                  -save current state
//   rollback                  -restore to last snapshot
//   drift                     -show which values have changed over time
//   env                       -show all current bindings
//   help                      -show command reference
//   quit / exit               -exit the shell

use "machine_vm.m"

// ── String helpers ───────────────────────────────────

fn str_starts_with(s: string, prefix: string) -> bool {
    if len(prefix) > len(s) { return false; }
    return str_eq(substr(s, 0, len(prefix)), prefix);
}

fn is_ws(c: i32) -> bool { return c == 32 || c == 9 || c == 10 || c == 13; }

fn str_trim(s: string) -> string {
    var start: i32 = 0;
    while start < len(s) && is_ws(char_at(s, start)) {
        start = start + 1;
    }
    var end: i32 = len(s);
    while end > start && is_ws(char_at(s, end - 1)) {
        end = end - 1;
    }
    return substr(s, start, end - start);
}

fn is_digit_char(c: i32) -> bool { return c >= 48 && c <= 57; }

fn str_to_int(s: string) -> i32 {
    var result: i32 = 0;
    var i: i32 = 0;
    var neg: bool = false;
    if len(s) > 0 && char_at(s, 0) == 45 {
        neg = true;
        i = 1;
    }
    while i < len(s) {
        let c: i32 = char_at(s, i);
        if !is_digit_char(c) { break; }
        result = result * 10 + (c - 48);
        i = i + 1;
    }
    if neg { return 0 - result; }
    return result;
}

fn is_number(s: string) -> bool {
    if len(s) == 0 { return false; }
    var i: i32 = 0;
    if char_at(s, 0) == 45 { i = 1; }
    if i >= len(s) { return false; }
    while i < len(s) {
        let c: i32 = char_at(s, i);
        if !is_digit_char(c) { return false; }
        i = i + 1;
    }
    return true;
}

fn find_char(s: string, c: i32) -> i32 {
    var i: i32 = 0;
    while i < len(s) {
        if char_at(s, i) == c { return i; }
        i = i + 1;
    }
    return 0 - 1;
}

// ── REPL display helpers ─────────────────────────────

fn print_val(vid: i32) {
    let t: i32 = val_get_type(vid);
    let conf: i32 = val_get_conf(vid);
    if t == VT_NIL() {
        print("nil");
    } else if t == VT_I32() {
        if conf < 100 {
            print("~");
            print(int_to_str(val_get_int(vid)));
            print(" (conf:");
            print(int_to_str(conf));
            print("%)");
        } else {
            print(int_to_str(val_get_int(vid)));
        }
    } else if t == VT_BOOL() {
        if val_get_int(vid) != 0 { print("true"); }
        else { print("false"); }
    } else if t == VT_STR() {
        print("\"");
        print(val_get_str(vid));
        print("\"");
    } else {
        print("?");
    }
}

fn show_help() {
    println("");
    println("  Machine REPL -Temporal Computing Shell");
    println("  ========================================");
    println("");
    println("  bind <name> = <value>   Bind a name to a value");
    println("  bind <name> ~ <value>   Bind with uncertainty (~approximate)");
    println("  load <name>             Show current value");
    println("  history <name>          Show full timeline");
    println("  forget <name>           Forget a binding");
    println("  snapshot                Save to memory (for rollback)");
    println("  rollback                Restore from memory snapshot");
    println("  save [path]             Save state to disk");
    println("  restore [path]          Restore state from disk");
    println("  drift                   Show value changes over time");
    println("  env                     Show all bindings");
    println("  help                    This message");
    println("  quit / exit             Exit (auto-saves)");
    println("");
    println("  Expressions are evaluated directly:");
    println("    2 + 3              -> 5");
    println("    x * 2 + 1          -> uses bound variables");
    println("    (10 + x) * 3       -> parentheses work");
    println("    x > 5 && x < 100   -> comparisons + logic");
    println("");
    println("  Values: integers (42), strings (\"hello\"), booleans (true/false)");
    println("  Approximate: bind x ~ 100  (value with uncertainty)");
    println("");
}

fn show_banner() {
    println("");
    println("  Machine -Temporal Computing Shell");
    println("  Tohum v0.1 | Type 'help' for commands");
    println("");
}

// ── Command parsing ──────────────────────────────────

fn parse_value(s: string) -> i32 {
    let trimmed: string = str_trim(s);
    if len(trimmed) == 0 { return val_nil(); }
    if str_eq(trimmed, "true") { return val_bool(1); }
    if str_eq(trimmed, "false") { return val_bool(0); }
    if str_eq(trimmed, "nil") { return val_nil(); }

    // String literal: "..."
    if len(trimmed) >= 2 && char_at(trimmed, 0) == 34 && char_at(trimmed, len(trimmed) - 1) == 34 {
        return val_str(substr(trimmed, 1, len(trimmed) - 2));
    }

    // Number
    if is_number(trimmed) {
        return val_i32(str_to_int(trimmed));
    }

    // Try to load as name reference
    let ref_slot: i32 = env_find(trimmed);
    if ref_slot >= 0 {
        return env_load(trimmed);
    }

    // Unknown -treat as string
    return val_str(trimmed);
}

fn cmd_bind(args: string) {
    // Find = or ~ operator
    let eq_pos: i32 = find_char(args, 61);  // '='
    let tilde_pos: i32 = find_char(args, 126);  // '~'

    var name: string = "";
    var value_str: string = "";
    var approx: bool = false;

    if tilde_pos >= 0 && (eq_pos < 0 || tilde_pos < eq_pos) {
        name = str_trim(substr(args, 0, tilde_pos));
        value_str = str_trim(substr(args, tilde_pos + 1, len(args) - tilde_pos - 1));
        approx = true;
    } else if eq_pos >= 0 {
        name = str_trim(substr(args, 0, eq_pos));
        value_str = str_trim(substr(args, eq_pos + 1, len(args) - eq_pos - 1));
    } else {
        println("  Error: use 'bind <name> = <value>' or 'bind <name> ~ <value>'");
        return;
    }

    if len(name) == 0 {
        println("  Error: name cannot be empty");
        return;
    }

    var vid: i32 = 0;
    if approx {
        if is_number(value_str) {
            vid = val_approx(str_to_int(value_str), 70);
        } else {
            println("  Error: approximate values must be numeric");
            return;
        }
    } else {
        vid = parse_value(value_str);
    }

    // Check if this is a rebind (name already exists)
    let existing: i32 = env_find(name);
    let tick: i32 = vm_get_tick();
    env_bind(name, vid, tick, "repl");

    print("  ");
    print(name);
    if existing >= 0 {
        print(" -> ");
    } else {
        print(" = ");
    }
    print_val(vid);
    println("");
}

fn cmd_load(args: string) {
    let name: string = str_trim(args);
    if len(name) == 0 {
        println("  Error: use 'load <name>'");
        return;
    }
    let slot: i32 = env_find(name);
    if slot < 0 {
        print("  '");
        print(name);
        println("' not found");
        return;
    }
    if env_is_forgotten(name) {
        print("  '");
        print(name);
        println("' was forgotten");
        return;
    }
    let vid: i32 = env_load(name);
    print("  ");
    print(name);
    print(" = ");
    print_val(vid);
    println("");
}

fn cmd_history(args: string) {
    let name: string = str_trim(args);
    if len(name) == 0 {
        println("  Error: use 'history <name>'");
        return;
    }
    let slot: i32 = env_find(name);
    if slot < 0 {
        print("  '");
        print(name);
        println("' not found");
        return;
    }

    let tl: i32 = env_get_timeline(name);
    let tlen: i32 = tl_length(tl);

    print("  ");
    print(name);
    print(" timeline (");
    print(int_to_str(tlen));
    println(" entries):");

    var i: i32 = 0;
    while i < tlen {
        let vid: i32 = tl_get_val(tl, i);
        let src: string = tl_get_source(tl, i);
        print("    [");
        print(int_to_str(i));
        print("] ");
        print_val(vid);
        if len(src) > 0 {
            print("  (");
            print(src);
            print(")");
        }
        if i == tlen - 1 { print("  <- current"); }
        println("");
        i = i + 1;
    }
}

fn cmd_forget(args: string) {
    let name: string = str_trim(args);
    if len(name) == 0 {
        println("  Error: use 'forget <name>'");
        return;
    }
    let slot: i32 = env_find(name);
    if slot < 0 {
        print("  '");
        print(name);
        println("' not found");
        return;
    }
    env_forget(name);
    print("  forgot '");
    print(name);
    println("'");
}

fn cmd_env() {
    let count: i32 = env_get_count();
    if count == 0 {
        println("  (no bindings)");
        return;
    }
    println("  Current bindings:");
    var i: i32 = 0;
    while i < count {
        let name: string = env_get_name(i);
        if len(name) > 0 && !env_is_forgotten(name) {
            let vid: i32 = env_load(name);
            print("    ");
            print(name);
            print(" = ");
            print_val(vid);

            // Show timeline length if > 1
            let tl: i32 = env_get_timeline(name);
            let tlen: i32 = tl_length(tl);
            if tlen > 1 {
                print("  (");
                print(int_to_str(tlen));
                print(" versions)");
            }
            println("");
        }
        i = i + 1;
    }
}

fn cmd_drift() {
    let count: i32 = env_get_count();
    if count == 0 {
        println("  (no bindings to analyze)");
        return;
    }
    var stable: i32 = 0;
    var changed: i32 = 0;
    println("  Drift analysis:");
    var i: i32 = 0;
    while i < count {
        let name: string = env_get_name(i);
        if len(name) > 0 {
            let tl: i32 = env_get_timeline(name);
            let tlen: i32 = tl_length(tl);
            if tlen > 1 {
                print("    ");
                print(name);
                print(": ");
                print_val(tl_get_val(tl, 0));
                print(" -> ");
                print_val(tl_get_val(tl, tlen - 1));
                print("  (");
                print(int_to_str(tlen));
                println(" changes)");
                changed = changed + 1;
            } else {
                stable = stable + 1;
            }
        }
        i = i + 1;
    }
    print("  stable: ");
    print(int_to_str(stable));
    print(", changed: ");
    println(int_to_str(changed));
}

fn cmd_snapshot() {
    vm_snapshot();
    println("  State saved.");
}

fn cmd_rollback() {
    let ok: i32 = vm_rollback();
    if ok == 0 {
        println("  Rolled back to last snapshot.");
    } else {
        println("  No snapshot to restore.");
    }
}

// Default state file path
fn state_path() -> string { return ".machine_state"; }

fn cmd_save(args: string) {
    var path: string = str_trim(args);
    if len(path) == 0 { path = state_path(); }
    let ok: i32 = vm_persist(path);
    if ok == 0 {
        print("  State saved to ");
        println(path);
    } else {
        println("  Error: could not save state");
    }
}

fn cmd_restore(args: string) {
    var path: string = str_trim(args);
    if len(path) == 0 { path = state_path(); }
    let ok: i32 = vm_restore(path);
    if ok == 0 {
        print("  State restored from ");
        println(path);
    } else {
        print("  No saved state at ");
        println(path);
    }
}

fn try_auto_restore() {
    // Silently try to restore default state file
    let data: string = read_file(state_path());
    if len(data) > 0 {
        vm_deserialize(data);
        print("  (restored ");
        print(int_to_str(env_get_count()));
        println(" bindings from previous session)");
    }
}

// ── Expression evaluator ─────────────────────────────
// Tokenizes, parses, compiles to VM bytecode, runs.
// Supports: integers, variables, +, -, *, /, %, (, ), unary -
// Comparisons: ==, !=, <, >, <=, >=
// Booleans: true, false, &&, ||, !

// Token types for expression parser
fn ET_NUM() -> i32   { return 1; }
fn ET_IDENT() -> i32 { return 2; }
fn ET_PLUS() -> i32  { return 3; }
fn ET_MINUS() -> i32 { return 4; }
fn ET_STAR() -> i32  { return 5; }
fn ET_SLASH() -> i32 { return 6; }
fn ET_MOD() -> i32   { return 7; }
fn ET_LPAREN() -> i32 { return 8; }
fn ET_RPAREN() -> i32 { return 9; }
fn ET_EOF2() -> i32  { return 10; }
fn ET_STR() -> i32   { return 11; }
fn ET_EQ() -> i32    { return 12; }
fn ET_NEQ() -> i32   { return 13; }
fn ET_LT() -> i32    { return 14; }
fn ET_GT() -> i32    { return 15; }
fn ET_LTE() -> i32   { return 16; }
fn ET_GTE() -> i32   { return 17; }
fn ET_AND() -> i32   { return 18; }
fn ET_OR() -> i32    { return 19; }
fn ET_NOT() -> i32   { return 20; }

// Expression tokenizer state
var etk_src: string = "";
var etk_pos: i32 = 0;
var etk_types: i32 = 0;
var etk_ivals: i32 = 0;
var etk_svals: i32 = 0;
var etk_count: i32 = 0;
var etk_cur: i32 = 0;

fn etk_is_alpha(c: i32) -> bool {
    if c >= 65 && c <= 90 { return true; }
    if c >= 97 && c <= 122 { return true; }
    return c == 95;
}

fn etk_tokenize(src: string) -> i32 {
    etk_src = src;
    etk_pos = 0;
    etk_types = array_new(0);
    etk_ivals = array_new(0);
    etk_svals = array_new(0);
    etk_count = 0;
    etk_cur = 0;

    while etk_pos < len(src) {
        let c: i32 = char_at(src, etk_pos);

        if c == 32 || c == 9 {
            etk_pos = etk_pos + 1;
        }
        else if is_digit_char(c) {
            var n: i32 = 0;
            while etk_pos < len(src) && is_digit_char(char_at(src, etk_pos)) {
                n = n * 10 + (char_at(src, etk_pos) - 48);
                etk_pos = etk_pos + 1;
            }
            array_push(etk_types, ET_NUM());
            array_push(etk_ivals, n);
            array_push(etk_svals, 0);
            etk_count = etk_count + 1;
        }
        else if etk_is_alpha(c) {
            var start: i32 = etk_pos;
            while etk_pos < len(src) && (etk_is_alpha(char_at(src, etk_pos)) || is_digit_char(char_at(src, etk_pos))) {
                etk_pos = etk_pos + 1;
            }
            let word: string = substr(src, start, etk_pos - start);
            array_push(etk_types, ET_IDENT());
            array_push(etk_ivals, 0);
            array_push(etk_svals, sp_store(word));
            etk_count = etk_count + 1;
        }
        else if c == 34 {
            etk_pos = etk_pos + 1;
            var start: i32 = etk_pos;
            while etk_pos < len(src) && char_at(src, etk_pos) != 34 {
                etk_pos = etk_pos + 1;
            }
            let s: string = substr(src, start, etk_pos - start);
            if etk_pos < len(src) { etk_pos = etk_pos + 1; }
            array_push(etk_types, ET_STR());
            array_push(etk_ivals, 0);
            array_push(etk_svals, sp_store(s));
            etk_count = etk_count + 1;
        }
        else if c == 61 && etk_pos + 1 < len(src) && char_at(src, etk_pos + 1) == 61 {
            array_push(etk_types, ET_EQ()); array_push(etk_ivals, 0); array_push(etk_svals, 0);
            etk_count = etk_count + 1; etk_pos = etk_pos + 2;
        }
        else if c == 33 && etk_pos + 1 < len(src) && char_at(src, etk_pos + 1) == 61 {
            array_push(etk_types, ET_NEQ()); array_push(etk_ivals, 0); array_push(etk_svals, 0);
            etk_count = etk_count + 1; etk_pos = etk_pos + 2;
        }
        else if c == 60 && etk_pos + 1 < len(src) && char_at(src, etk_pos + 1) == 61 {
            array_push(etk_types, ET_LTE()); array_push(etk_ivals, 0); array_push(etk_svals, 0);
            etk_count = etk_count + 1; etk_pos = etk_pos + 2;
        }
        else if c == 62 && etk_pos + 1 < len(src) && char_at(src, etk_pos + 1) == 61 {
            array_push(etk_types, ET_GTE()); array_push(etk_ivals, 0); array_push(etk_svals, 0);
            etk_count = etk_count + 1; etk_pos = etk_pos + 2;
        }
        else if c == 38 && etk_pos + 1 < len(src) && char_at(src, etk_pos + 1) == 38 {
            array_push(etk_types, ET_AND()); array_push(etk_ivals, 0); array_push(etk_svals, 0);
            etk_count = etk_count + 1; etk_pos = etk_pos + 2;
        }
        else if c == 124 && etk_pos + 1 < len(src) && char_at(src, etk_pos + 1) == 124 {
            array_push(etk_types, ET_OR()); array_push(etk_ivals, 0); array_push(etk_svals, 0);
            etk_count = etk_count + 1; etk_pos = etk_pos + 2;
        }
        else if c == 43 { array_push(etk_types, ET_PLUS()); array_push(etk_ivals, 0); array_push(etk_svals, 0); etk_count = etk_count + 1; etk_pos = etk_pos + 1; }
        else if c == 45 { array_push(etk_types, ET_MINUS()); array_push(etk_ivals, 0); array_push(etk_svals, 0); etk_count = etk_count + 1; etk_pos = etk_pos + 1; }
        else if c == 42 { array_push(etk_types, ET_STAR()); array_push(etk_ivals, 0); array_push(etk_svals, 0); etk_count = etk_count + 1; etk_pos = etk_pos + 1; }
        else if c == 47 { array_push(etk_types, ET_SLASH()); array_push(etk_ivals, 0); array_push(etk_svals, 0); etk_count = etk_count + 1; etk_pos = etk_pos + 1; }
        else if c == 37 { array_push(etk_types, ET_MOD()); array_push(etk_ivals, 0); array_push(etk_svals, 0); etk_count = etk_count + 1; etk_pos = etk_pos + 1; }
        else if c == 40 { array_push(etk_types, ET_LPAREN()); array_push(etk_ivals, 0); array_push(etk_svals, 0); etk_count = etk_count + 1; etk_pos = etk_pos + 1; }
        else if c == 41 { array_push(etk_types, ET_RPAREN()); array_push(etk_ivals, 0); array_push(etk_svals, 0); etk_count = etk_count + 1; etk_pos = etk_pos + 1; }
        else if c == 60 { array_push(etk_types, ET_LT()); array_push(etk_ivals, 0); array_push(etk_svals, 0); etk_count = etk_count + 1; etk_pos = etk_pos + 1; }
        else if c == 62 { array_push(etk_types, ET_GT()); array_push(etk_ivals, 0); array_push(etk_svals, 0); etk_count = etk_count + 1; etk_pos = etk_pos + 1; }
        else if c == 33 { array_push(etk_types, ET_NOT()); array_push(etk_ivals, 0); array_push(etk_svals, 0); etk_count = etk_count + 1; etk_pos = etk_pos + 1; }
        else {
            etk_pos = etk_pos + 1;
        }
    }

    array_push(etk_types, ET_EOF2());
    array_push(etk_ivals, 0);
    array_push(etk_svals, 0);
    etk_count = etk_count + 1;
    return etk_count;
}

fn etk_type() -> i32 { return array_get(etk_types, etk_cur); }
fn etk_ival() -> i32 { return array_get(etk_ivals, etk_cur); }
fn etk_sval() -> string { return sp_get(array_get(etk_svals, etk_cur)); }
fn etk_advance() { etk_cur = etk_cur + 1; }

// ── Recursive descent parser -> VM bytecode ──────────
// Precedence (low to high):
//   ||  ->  &&  ->  ==,!=  ->  <,>,<=,>=  ->  +,-  ->  *,/,%  ->  unary -,!  ->  atom

var expr_error: bool = false;

fn parse_expr() {
    parse_or();
}

fn parse_or() {
    parse_and();
    while etk_type() == ET_OR() && !expr_error {
        etk_advance();
        parse_and();
        code_add(OP_OR());
    }
}

fn parse_and() {
    parse_equality();
    while etk_type() == ET_AND() && !expr_error {
        etk_advance();
        parse_equality();
        code_add(OP_AND());
    }
}

fn parse_equality() {
    parse_comparison();
    while (etk_type() == ET_EQ() || etk_type() == ET_NEQ()) && !expr_error {
        let op: i32 = etk_type();
        etk_advance();
        parse_comparison();
        if op == ET_EQ() { code_add(OP_EQ()); }
        else { code_add(OP_NEQ()); }
    }
}

fn parse_comparison() {
    parse_additive();
    while (etk_type() == ET_LT() || etk_type() == ET_GT() || etk_type() == ET_LTE() || etk_type() == ET_GTE()) && !expr_error {
        let op: i32 = etk_type();
        etk_advance();
        parse_additive();
        if op == ET_LT() { code_add(OP_LT()); }
        else if op == ET_GT() { code_add(OP_GT()); }
        else if op == ET_LTE() { code_add(OP_LTE()); }
        else { code_add(OP_GTE()); }
    }
}

fn parse_additive() {
    parse_multiplicative();
    while (etk_type() == ET_PLUS() || etk_type() == ET_MINUS()) && !expr_error {
        let op: i32 = etk_type();
        etk_advance();
        parse_multiplicative();
        if op == ET_PLUS() { code_add(OP_ADD()); }
        else { code_add(OP_SUB()); }
    }
}

fn parse_multiplicative() {
    parse_unary();
    while (etk_type() == ET_STAR() || etk_type() == ET_SLASH() || etk_type() == ET_MOD()) && !expr_error {
        let op: i32 = etk_type();
        etk_advance();
        parse_unary();
        if op == ET_STAR() { code_add(OP_MUL()); }
        else if op == ET_SLASH() { code_add(OP_DIV()); }
        else { code_add(OP_MOD()); }
    }
}

fn parse_unary() {
    if etk_type() == ET_MINUS() {
        etk_advance();
        parse_unary();
        code_add(OP_NEG());
    } else if etk_type() == ET_NOT() {
        etk_advance();
        parse_unary();
        code_add(OP_NOT());
    } else {
        parse_atom();
    }
}

fn parse_atom() {
    let t: i32 = etk_type();

    if t == ET_NUM() {
        code_add(OP_PUSH_I32());
        code_add(etk_ival());
        etk_advance();
    }
    else if t == ET_STR() {
        let ni: i32 = name_add(etk_sval());
        code_add(OP_PUSH_STR());
        code_add(ni);
        etk_advance();
    }
    else if t == ET_IDENT() {
        let word: string = etk_sval();
        if str_eq(word, "true") {
            code_add(OP_PUSH_BOOL());
            code_add(1);
        } else if str_eq(word, "false") {
            code_add(OP_PUSH_BOOL());
            code_add(0);
        } else if str_eq(word, "nil") {
            code_add(OP_PUSH_NIL());
        } else {
            let ni: i32 = name_add(word);
            code_add(OP_LOAD());
            code_add(ni);
        }
        etk_advance();
    }
    else if t == ET_LPAREN() {
        etk_advance();
        parse_expr();
        if etk_type() == ET_RPAREN() {
            etk_advance();
        } else {
            expr_error = true;
            println("  Error: expected ')'");
        }
    }
    else {
        expr_error = true;
    }
}

// ── Evaluate expression string ───────────────────────

fn eval_expression(src: string) {
    etk_tokenize(src);
    expr_error = false;

    vm_reset_code();
    parse_expr();

    if expr_error { return; }

    if etk_type() != ET_EOF2() {
        println("  Error: unexpected input after expression");
        return;
    }

    code_add(OP_HALT());
    vm_run();

    if stack_top > 0 {
        let result: i32 = stack_peek();
        print("  = ");
        print_val(result);
        println("");
    }
}

// ── Main REPL loop ───────────────────────────────────

fn main() -> i32 {
    vm_init();

    show_banner();

    var running: bool = true;
    while running {
        print("machine> ");
        flush();
        let input: string = read_line();

        // EOF detection: read_line returns \x04 on EOF
        if len(input) == 1 && char_at(input, 0) == 4 {
            running = false;
            break;
        }

        let line: string = str_trim(input);

        if len(line) == 0 {
            // empty line, continue
        } else if str_eq(line, "quit") || str_eq(line, "exit") {
            running = false;
        } else if str_eq(line, "help") {
            show_help();
        } else if str_eq(line, "env") {
            cmd_env();
        } else if str_eq(line, "drift") {
            cmd_drift();
        } else if str_eq(line, "snapshot") {
            cmd_snapshot();
        } else if str_eq(line, "rollback") {
            cmd_rollback();
        } else if str_eq(line, "save") || str_starts_with(line, "save ") {
            if len(line) > 5 { cmd_save(substr(line, 5, len(line) - 5)); }
            else { cmd_save(""); }
        } else if str_eq(line, "restore") || str_starts_with(line, "restore ") {
            if len(line) > 8 { cmd_restore(substr(line, 8, len(line) - 8)); }
            else { cmd_restore(""); }
        } else if str_starts_with(line, "bind ") {
            cmd_bind(substr(line, 5, len(line) - 5));
        } else if str_starts_with(line, "load ") {
            cmd_load(substr(line, 5, len(line) - 5));
        } else if str_starts_with(line, "history ") {
            cmd_history(substr(line, 8, len(line) - 8));
        } else if str_starts_with(line, "forget ") {
            cmd_forget(substr(line, 7, len(line) - 7));
        } else {
            // Try as expression
            eval_expression(line);
        }
    }

    // Auto-save on exit
    if env_get_count() > 0 {
        vm_persist(state_path());
    }

    println("");
    println("  Goodbye.");
    return 0;
}
