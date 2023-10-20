module lfun;

// fun lexer, parser, and evaluator

import std.stdio : writefln;
import std.ascii : isDigit;
import std.conv : to;
import std.string : strip;

import ffun;

enum funState
{
    start,
    comment,
    args,
    str
}

funTokenType token_type(char c)
{
    if (c == '\n')
    {
        return funTokenType.newline;
    }

    if (isDigit(c))
    {
        return funTokenType.number;
    }

    if (c == ' ')
    {
        return funTokenType.space;
    }

    if (c == '"')
    {
        return funTokenType.str_quote;
    }

    if (!isDigit(c))
    {
        return funTokenType.plain;
    }

    return funTokenType.none;
}

enum declState
{
    start,
    name,
    block,
    str,
    end
}

const char DECL_BLOCK_START = '{';
const char DECL_BLOCK_END = '}';

struct LexState
{

}

// checks if theres a string and returns TRUE if it's currently parsing a string
// or FALSE if there is none
bool lex_string_check(declState* prev, declState* state, char c)
{
    if (*state != state.str && c == '"')
    {
        prev = state;
        *state = state.str;
        return true;
    }
    else
    {
        state = prev;
        return false;
    }
}

/* 
parses something similar to:

fn main {
    print "Hello, world!";
}
*/
decl[] parse_declarations(string stak)
{
    decl[] decs;
    decl dec;

    declState prev = declState.start;
    declState state = declState.start;

    string tmp = "";

    for (int i = 0; i < stak.length; i++)
    {
        char c = stak[i];

        // if (!lex_string_check(&prev, &state, c)) {
        //     goto add;
        // }

        if (state == declState.start && token_type(c) == funTokenType.space) /* fn-[space] ... */
        {
            state = declState.name;
            dec.top_name = strip(tmp);
        clear:
            tmp = "";
        }
        else if (state == declState.name && c == DECL_BLOCK_START) /* fn [nam...] ( { ) */
        {
            dec.fn_name = strip(tmp);

            state = declState.block;

            goto clear;
        }
        else if (state == declState.block && c == DECL_BLOCK_START) /* fn [nam...] { ( { ) ... } */
        {
            fn_error("nesting in fn declaration not allowed");
        }
        else if (state == declState.block && c == DECL_BLOCK_END) /* fn [nam...] { ... ( } ) */
        {
            state = declState.start;

            dec.callstack = parse_callstack(strip(tmp));

            decs ~= dec;

            dec = decl();

            goto clear;
        }
        else
        {
        add:
            tmp ~= c;
        }
    }
    return decs;

}

fn[] parse_callstack(string stak)
{
    fn[] callstack;
    stak = strip(stak);

    string[] stats;
    string tmp;

    auto end = (int n) => (n >= stak.length - 1);

    funState state = funState.start;
    funState prev_state = state;

    for (int i = 0; i < stak.length; i++)
    {
        char c = stak[i];

        if (token_type(c) == funTokenType.str_quote && state != funState.str)
        {
            prev_state = state;
            state = funState.str;
            goto add;
        }
        else if (token_type(c) == funTokenType.str_quote && state == funState.str)
        {
            state = prev_state;
            prev_state = state;
            goto add;
        }
        else if ((token_type(c) == funTokenType.newline ||
                end(i)) && state != funState.str)
        {
            tmp ~= c;
            stats ~= strip(tmp);
            tmp = "";
        }
        else
        {
        add:
            tmp ~= c;
        }
    }
    if (tmp.length > 0)
    {
        stats ~= strip(tmp);
        tmp = "";
    }
    foreach (string s; stats)
    {
        callstack ~= parse_fn_call(s);
    }

    return callstack;
}

// parse a function call
fn parse_fn_call(string s)
{
    funState state = funState.start;
    funState prev_state = state;
    auto end = (int n) => (n >= s.length - 1);

    string fname = "";
    string tmp = "";
    val[] args;

    for (int i = 0; i < s.length; i++)
    {
        char c = s[i];

        if (token_type(c) == funTokenType.space)
        {
            if (state == funState.start)
            {
                fname = tmp;

                state = funState.args;
                tmp = "";
            }
            else if (state == funState.args)
            {
            add:
                args ~= val_create(tmp);
                tmp = "";

            }
            else
            {
                goto add_c;
            }
        }
        else if (token_type(c) == funTokenType.str_quote && state != funState.str)
        {
            prev_state = state;
            state = funState.str;
            goto add_c;
        }
        else if (token_type(c) == funTokenType.str_quote && state == funState.str)
        {
            state = prev_state;
            prev_state = state;
            goto add_c;
        }
        else
        {
        add_c:
            tmp ~= c;
        }

        if (token_type(c) == funTokenType.number && state == funState.start)
        {
            fn_error("expected function name, got NUMBER");
        }

        if (end(i))
        {
            if (state == funState.args && strip(tmp).length > 0)
                goto add;
        }
    }

    fn f = fn_create(fname, args);

    return f;
}

// if the file starts off with declarations
bool is_decl_based(string stat)
{
    bool yn = false;

    foreach (char c; stat)
    {
        if (c == '{')
        {
            yn = true;
            break;
        }
    }

    return yn;
}

bool env_has_variable(env* e, val v)
{
    foreach (string n; keys(e.variables))
    {
        if (n == v.value) /* equal to the value put in */
        {
            return true;
        }
    }
    return false;
}

val env_get_variable(env* e, val v)
{
    foreach (string n; keys(e.variables))
    {
        if (n == v.value) /* equal to the value put in */
        {
            return e.variables[n];
        }
    }
    return val_create("");
}

void env_add_variable(env* e, string name, val v)
{
    e.variables[name] = v;
}

void env_edit_variable(env* e, string name, val v)
{
    e.variables[name] = v;
}

void env_add_function(env * e, string name, val function(val[] args, env* e) n)
{
    e.builtins[name] = n;
}

// goes into {STAT}, replacing all instances of variables from the environment with their values
decl[] lex_replace_with_variables(env* v, string stat)
{
    auto l = parse_declarations(stat);

    if (is_decl_based(stat))
    {
        for (int i = 0; i < l.length; i++) // moving through the declarations
        {
            // if (zv.type == funType.var)
            // {
            //     if (env_has_variable(v, zv))
            //     {
            //         zv = env_get_variable(v, zv);

            //         writefln("%s", zv);

            //         writefln("%s", zv.value);

            //     }
            // }
            for (int j = 0; j < l[i].callstack.length; j++) { // moving through the callstack

                for (int k = 0; k < l[i].callstack[j].vals.length; k++) {
                    if (l[i].callstack[j].vals[k].type == funType.var)
                    {
                        if (env_has_variable(v, l[i].callstack[j].vals[k]))
                        {
                            l[i].callstack[j].vals[k] = env_get_variable(v, l[i].callstack[j].vals[k]);
                        } else {
                            fn_error ("variable '" ~ l[i].callstack[j].vals[k].value ~ "' not found");
                        }
                    }
                }
            }
        }
    }

    return l;
}

void fun_run_decl(env* e, decl dec)
{
    foreach (decla; e.declarations)
    {
        if (dec.fn_name == decla.fn_name)
        {
            foreach (fn; dec.callstack)
            {
                fn_evaluate(e, fn);
            }
        }
    }
}

bool decl_exists(env* e, string name)
{
    foreach (decl; e.declarations)
    {
        if (name == decl.fn_name)
        {
            return true;
        }
    }
    return false;
}

void run_decl(env* e, string name)
{
    foreach (decl; e.declarations)
    {
        if (name == decl.fn_name)
        {
            foreach (fn; decl.callstack)
            {
                fn_evaluate(e, fn);
            }
        }
    }
}

val fn_run(val[] v, env* e)
{
    fn n = fn_find(*e, val_to_string(v[0]));

    if (!decl_exists(e, val_to_string(v[0])))
    {
        fn_error("do: function '" ~ val_to_string(v[0]) ~ "' not found");
    }
    else
    {
        run_decl(e, val_to_string(v[0]));
    }
    return cast(val) null;
}

void add_lexical_builtins(env* e)
{
    auto env_builtins_has = (string n) => {
        foreach (f; e.builtins.keys())
        {
            if (strip(f) == strip(n))
            {
                return true;
            }
        }
        return false;
    };

    // if (!env_builtins_has("do"))
    e.builtins["do"] = &fn_run;
}

void fun_run(env* e, string blok)
{
    add_lexical_builtins(e);

    decl[] decs = parse_declarations(blok);
    decs = lex_replace_with_variables(e, blok);
    foreach (decl; decs)
    {
        e.declarations ~= decl;
    }
}

void fun_main(env* e)
{
    foreach (decl; e.declarations)
    {
        if (decl.fn_name == "main")
        {
            foreach (fn; decl.callstack)
            {
                fn_evaluate(e, fn);
            }
        }
    }
}
