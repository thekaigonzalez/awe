module main;

import std.stdio : writefln;
import std.ascii : isDigit;
import std.file : readText;
import std.conv : to;

import ffun;
import lfun;

val example_add(val[] args, env* e) {
    val a = args[0];
    val b = args[1];

    val c = val_create(to!string(val_to_number(a) + val_to_number(b)));
    
    e.variables["@"] = c;

    return val_create("0");
}

void main(string[] argv)
{
    env e;

    env_initialize(&e);

    string text = readText(argv[1]);

    env_add_function(&e, "add", &example_add);
    
    fun_run(&e, text);

    fun_main(&e);
}
