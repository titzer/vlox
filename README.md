# Vlox

A bytecode virtual machine for **Lox**, the language from Robert Nystrom's
*[Crafting Interpreters](https://craftinginterpreters.com/)*, written in
[Virgil](https://github.com/titzer/virgil).

The twist: instead of clox's purpose-built opcode set, Vlox compiles Lox to a
bytecode that **is a subset of the WebAssembly binary encoding**. Control flow is
`block`/`loop`/`if`/`br`. Variables are Wasm locals and globals. Everything Lox
needs that Wasm has no opcode for — dynamic addition, property access, method
dispatch, closure construction — is a `call` to a *runtime intrinsic* occupying the
low end of the function index space, exactly where a real module's imports live.

There is no Vlox-private opcode space at all. Every byte the compiler emits is a
real Wasm opcode with real Wasm immediates. `DESIGN.md` is the full specification;
here is the flavour of it:

```
                             ;; while (i < 3) { ... }
block                        ;; 0x02 0x40
  loop                       ;; 0x03 0x40
    local.get 1              ;; 0x20 0x01
    global.get 3             ;; 0x23 0x03   -- the constant 3
    call 9                   ;; 0x10 0x09   -- lox.lt
    call 0                   ;;             -- lox.truthy : lox -> i32
    i32.eqz                  ;; 0x45
    br_if 1                  ;; 0x0D 0x01   -- exit the block
    ...
    br 0                     ;; 0x0C 0x00   -- back to the loop head
  end
end
```

## Building and running

Vlox needs a [Virgil](https://github.com/titzer/virgil) checkout. Point
`VIRGIL_LOC` at it (the default is `~/virgil`).

```sh
./build.sh                  # native binary for this host -> bin/vlox
./build.sh x86-64-linux     # or any Virgil target: jar, wasm-wasi1, arm64-linux, ...

bin/vlox program.lox        # run
bin/vlox -d program.lox     # disassemble the compiled Wasm and exit
bin/vlox -c program.lox     # compile only
```

Exit codes follow the reference implementations: `65` for a compile error, `70`
for a runtime error, `0` otherwise.

## Testing

```sh
./test/all.bash             # everything
./test/all.bash lox         # just one suite
./test/all.bash -v          # list every test
```

| suite | what it is |
|---|---|
| `test/lox` | the Crafting Interpreters suite, imported verbatim (241 tests) |
| `test/vlox` | tests written for Vlox, covering the decisions it makes differently |
| `test/bytecode` | golden files over the disassembled bytecode |

See `test/README.md` for the expectation format and the list of reference tests
that do not apply.

## How it is put together

Unlike clox, Vlox has a real front end rather than a single-pass compiler, because
Wasm locals are not addressable and closure capture therefore has to be decided
before code is emitted.

| file | |
|---|---|
| `src/Lexer.v3` | scanner; tokens carry begin/end source ranges |
| `src/Ast.v3` | AST nodes, annotated in place by the resolver |
| `src/Parser.v3` | recursive descent, with clox's exact messages and panic-mode recovery |
| `src/Resolver.v3` | scopes, local slots, and which locals must be boxed for capture |
| `src/Wasm.v3` | opcodes, LEB128 decoding, and the `DataWriter`-backed code buffer |
| `src/Module.v3` | global index space (constants *and* Lox globals), function index space, name pool |
| `src/Compiler.v3` | AST → Wasm bytecode |
| `src/Value.v3` | Lox values and heap objects |
| `src/Numbers.v3` | exact `%g` formatting, which Lox's `print` requires |
| `src/Interpreter.v3` | the VM: a Wasm interpreter plus the Lox intrinsics |
| `src/Disasm.v3` | Wasm text-format listing |

The one design decision worth calling out here, because it drives everything else:
**clox's open upvalues cannot work on Wasm locals.** clox captures a variable by
pointing an upvalue at its stack slot and closing it on scope exit; a Wasm local has
no address. So the resolver runs first and marks every local that an inner function
mentions, and the compiler stores those in a heap cell from the moment they are
declared. Closures capture the cell. That removes `OP_CLOSE_UPVALUE`, the open
upvalue list, and the whole scope-exit protocol — and it is what a real Wasm backend
would have to do anyway.

## Status

Complete Lox: closures, classes, inheritance, `super`, initializers, the `clock`
builtin, and the reference implementations' exact error messages, stack traces and
exit codes.

Not yet done: emitting an actual `.wasm` module. The bytecode is already in the
right encoding; what is missing is the module envelope (type, import, function,
global and code sections) and the intrinsics as real Wasm function bodies.

## License

Apache 2.0. `test/lox/` is imported from
[munificent/craftinginterpreters](https://github.com/munificent/craftinginterpreters)
under its MIT license; see `test/lox/LICENSE`.
