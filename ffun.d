module ffun;

// fun functions

import std.stdio : writefln;
import std.ascii : isDigit;
import std.conv : to;
import std.string : strip, startsWith;
import core.stdc.stdlib;
import std.algorithm.searching : canFind;

enum funType
{
    str,
    number,
    none,
    var
}

enum funTokenType
{
    str_start,
    number,
    str_quote,
    plain,
    none,
    space,
    newline
}

struct token
{
    char t;
    funTokenType type;
}

token token_create(char t, funTokenType type)
{
    token token;

    token.t = t;
    token.type = type;

    return token;
}

struct val
{
    string value;
    funType type;
}

funType val_validate_type(string value)
{
    funType t = funType.none;

    if (startsWith(strip(value), '"'))
    {
        t = funType.str;
        return t;
    }

    foreach (char c; value)
    {
        if (isDigit(c))
        {
            t = funType.number;
        }

        else if (!isDigit(c) && (t != funType.number || t != funType.str))
        {
            t = funType.var;
        }

        else if (!isDigit(c) && t == funType.number)
        {
            fn_error("malformed number");
        }
    }

    return t;
}

enum funStrState
{
    start,
    inside,
    end
}

string val_parse_string(string s)
{
    if (!startsWith(s, '"'))
    {
        fn_error("not a string that starts with quotes");
    }

    funStrState state = funStrState.start;

    string newstr = "";

    int i = 0;
    foreach (char c; s)
    {
        if (c == '"' && state == funStrState.start)
        {
            state = funStrState.inside;
        }

        else if (c == '"' && state == funStrState.inside && s[i - 1] != '\\')
        {
            state = funStrState.end;
        }

        else
        {
            newstr ~= c;
        }
        i++;
    }

    if (state != funStrState.end)
    {
        fn_error("malformed string");
    }

    return newstr;
}

val val_create(string value)
{
    val val;

    val.value = strip(value);
    val.type = val_validate_type(strip(value));

    if (val.type == funType.str)
    {
        val.value = val_parse_string(strip(value));
    }

    return val;
}

string val_to_string(val val)
{
    if (val.type == funType.number)
    {
        return to!string(val.value);
    }
    return val.value;
}

int val_to_number(val val)
{
    if (val.type != funType.number)
    {
        fn_error("not a number");
    }
    return to!int(val.value);
}

void fn_error(string msg)
{
    writefln("ERROR: %s", msg);
    exit(-1);
}

// contains a function name and it's valuments
struct fn
{
    string fn_name;
    val[] vals;
}

// contains an environment of built in functions
struct env
{
    // note: builtins are separated from the user functions to prevent any
    // overwrites or conflicts, which fun does not allow for simplicity reasons.
    val function(val[], env*)[string] builtins;
    fn[] user;
    decl[] declarations;

    val last; // the last value that can be pushed to the stack
    val[string] variables;
}

// contains information about a declaration
struct decl {
    string top_name;
    string fn_name;

    fn[] callstack;
}

// a simple stack with an environment (an environment that contains variables)
struct stack
{
    env environment_fn;
}

struct fn_status
{
    int status;
}

fn fn_create(string fn_name, val[] vals)
{
    fn fun;

    fun.fn_name = fn_name;
    fun.vals = vals;

    return fun;
}

fn fn_find(env e, string fn_name)
{
    foreach (fn fun; e.user)
    {
        if (fun.fn_name == fn_name)
            return fun;
    }
    return cast(fn) null;
}

val[] fn_get_vals(fn fun)
{
    return fun.vals;
}

val fn_get_val(fn fun, int i)
{
    if (i >= 0 && i < (fun.vals).length)
        return fun.vals[i];

    return cast(val) null;
}

void env_append_fn(env* e, fn fun)
{
    e.user ~= (fun); // ! no appending to builtins
}

void fn_stack_append(stack* s, fn fun)
{
    env_append_fn(&s.environment_fn, fun);
}

val fn_print(val[] v, env * e)
{
    foreach (val val; v)
    {
        writefln("%s", val_to_string(val));
    }
    return cast(val) null;
}

bool fn_exists(env* e, string fn_name) {
    foreach (fn fun; e.user)
    {
        if (strip(fun.fn_name) == strip(fn_name))
            return true;
    }
    return false;
}

void env_initialize(env* e)
{
    e.builtins = ["print": &fn_print];
}

fn[] fn_stack_get(stack s)
{
    return s.environment_fn.user;
}

void fn_set_status(fn_status* stat, int status)
{
    stat.status = status;
}

bool env_function_exists(env* e, string fn_name)
{
    foreach (fun; keys(e.builtins))
    {
        if (strip(fun) == strip(fn_name))
            return true;
    }
    return false;
}

// evaluates the parameters and valuments in a function
fn_status fn_evaluate(env* e, fn fun)
{
    fn_status stat;

    fn_set_status(&stat, 0);

    if (fun.vals.length == 0)
    {
        fn_set_status(&stat, 1);
        return stat;
    }

    if (env_function_exists(e, fun.fn_name))
    {
        e.builtins[fun.fn_name](fun.vals, e);
    } else {
        fn_error("function '" ~ fun.fn_name ~ "' not found");
    }

    return stat;
}
