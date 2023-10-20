# awe / fun

a simple language designed to be useful for understanding control flow, making
it a good programming language to learn about and teach.

## Getting started

```fun
fn main {
    do pmain;
}

fn pmain {
    print "hello from pmain!";
    do final;
}

fn final {
    print "hello from final!";
}

```

## How it works

* Every file starts with declarations
* Those declarations then get broken down into what's known as a "call stack"
* The call stack is a stack of functions to be executed in order
* Each function in the call stack is ran
* Close the block, rinse and repeat
