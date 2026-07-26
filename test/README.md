# Vlox tests

```sh
./test/all.bash                     # every suite
./test/all.bash lox vlox            # named suites only
./test/all.bash -v                  # list every test
python3 test/runner.py test/vlox/closure   # one directory or one file
./test/bytecode/run.bash -u         # re-record the bytecode goldens
```

## Suites

**`lox/`** — the [Crafting Interpreters](https://github.com/munificent/craftinginterpreters)
suite, imported verbatim (MIT, see `lox/LICENSE`). `scanning/` and `expressions/`
are not included: they test chapter-specific debug output that no finished
implementation produces. `benchmark/` is not included either; it has no
expectations.

**`vlox/`** — tests written for Vlox. They cover the places where Vlox's design
differs from clox's, plus areas the reference suite touches only lightly:

| directory | |
|---|---|
| `number/` | `%g` formatting across the fixed/scientific boundary, IEEE edge cases |
| `string/` | concatenation, interning |
| `closure/` | capture through deep nesting, per-iteration bindings, self-recursive locals, captured parameters and `this` |
| `control/` | `and`/`or` value semantics, nested `block`/`loop` nests, dangling `else`, returning out of several structured blocks at once |
| `class/` | multi-level `super`, bound methods, fields shadowing methods, local classes referring to themselves |
| `limit/` | **the clox limits Vlox does not have** — see below |
| `error/` | runtime error messages, stack traces, late-bound globals |

**`bytecode/`** — golden-file tests. Each `cases/*.lox` is disassembled with
`vlox -d` and diffed against `expected/*.wat`, so a change in codegen shows up as a
readable diff rather than as a mysterious behaviour change.

## Expectation format

The runner reads expectations out of the `.lox` source, in the format the reference
suite uses, so imported and new tests share one harness:

```lox
print 1 + 1;            // expect: 2

foo();                  // expect runtime error: Undefined variable 'foo'.
                        //   -> exit 70, message on stderr, stack trace naming this line

var 1;                  // Error at '1': Expect variable name.
                        //   -> exit 65, compile error reported on this line
                        // [line 7] Error: Unexpected character.
                        //   -> exit 65, compile error reported on line 7

// nontest              -> the file is not a test
```

A `SKIP` file in a directory lists tests that do not apply, one `path: reason` per
line.

## The clox limits Vlox does not have

Five reference tests assert limits that come from clox's *chunk format*, not from
the Lox language. Vlox's bytecode is WebAssembly, where every index is LEB128 and
control flow is structured, so none of them exist. They are listed in `lox/SKIP`,
and `vlox/limit/` tests the opposite — that programs which exceed each clox limit
compile and run correctly:

| clox limit | reference test (skipped) | Vlox test |
|---|---|---|
| 256 constants per chunk | `limit/too_many_constants.lox` | `vlox/limit/many_constants.lox` (400) |
| constants not reused across chunks | `limit/no_reuse_constants.lox` | `vlox/limit/many_constants.lox` |
| 256 locals per function | `limit/too_many_locals.lox` | `vlox/limit/many_locals.lox` (300) |
| 256 upvalues per closure | `limit/too_many_upvalues.lox` | `vlox/limit/many_upvalues.lox` (300) |
| 65535-byte loop body | `limit/loop_too_large.lox` | `vlox/limit/huge_loop_body.lox` |

The two limits that belong to the *language* — 255 parameters and 255 arguments —
are enforced, so `lox/limit/too_many_parameters.lox`, `too_many_arguments.lox` and
`stack_overflow.lox` all run and pass, and `vlox/limit/max_arity.lox` checks that
exactly 255 is still legal.
