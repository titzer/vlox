# Vlox bytecode design

Vlox compiles Lox to a bytecode that is a **strict subset of the WebAssembly binary
instruction encoding**. Every byte the compiler emits is either

  1. a real Wasm opcode with its real Wasm immediates, or
  2. a `call <funcidx>` to one of a fixed set of *runtime intrinsics* that occupy the
     low end of the function index space, exactly as imported functions do in a real
     Wasm module.

Nothing else exists. There is no Vlox-private opcode space. This means the bytecode a
Vlox function carries can (modulo emitting the surrounding module sections) be handed
to a Wasm decoder as-is, and it means the eventual "emit real WebAssembly" backend is a
matter of writing the module envelope plus supplying the intrinsics as imports or as
generated Wasm functions.

The interpreter in `src/Interpreter.v3` does *not* actually make a call for the
intrinsics; it decodes the `call` immediate, sees that it is below `Wasm.NUM_INTRINSICS`
and dispatches to a handler inline. That is an implementation choice of the interpreter,
not a property of the bytecode.

## 1. The value type

A Wasm module for Lox needs exactly one value type for Lox values. Vlox calls it `lox`
and encodes it with the byte `0x6F` (`externref`), the natural encoding until the Wasm-GC
struct types for a real backend are pinned down. A future backend can substitute
`(ref null $LoxValue)` without changing a single instruction.

`i32` (`0x7F`) appears in exactly two roles:

  * as the type of a **condition** consumed by `if` / `br_if`, and
  * as the type of **immediate operands pushed with `i32.const` for an intrinsic**
    (a constant-pool index, an argument count, a name index...).

Because Wasm `call` has exactly one immediate (the function index), an intrinsic that
conceptually takes an immediate takes it as an `i32` operand pushed by a preceding
`i32.const`. The pair `i32.const N` + `call $intrinsic` is therefore the Vlox spelling
of "high-level opcode with immediate N". It stays decodable, stays typed, and constant
folding in a real backend turns it back into an immediate.

## 2. Native Wasm opcodes used

| mnemonic     | hex  | immediates          | notes |
|--------------|------|---------------------|-------|
| `unreachable`| 0x00 |                     | trap |
| `nop`        | 0x01 |                     | |
| `block`      | 0x02 | blocktype           | |
| `loop`       | 0x03 | blocktype           | |
| `if`         | 0x04 | blocktype           | pops `i32` |
| `else`       | 0x05 |                     | |
| `end`        | 0x0B |                     | |
| `br`         | 0x0C | labelidx (uleb)     | |
| `br_if`      | 0x0D | labelidx (uleb)     | pops `i32` |
| `return`     | 0x0F |                     | |
| `call`       | 0x10 | funcidx (uleb)      | intrinsic if `< NUM_INTRINSICS` |
| `drop`       | 0x1A |                     | |
| `local.get`  | 0x20 | localidx (uleb)     | |
| `local.set`  | 0x21 | localidx (uleb)     | |
| `local.tee`  | 0x22 | localidx (uleb)     | |
| `global.get` | 0x23 | globalidx (uleb)    | |
| `global.set` | 0x24 | globalidx (uleb)    | |
| `i32.const`  | 0x41 | i32 (sleb)          | |
| `i32.eqz`    | 0x45 |                     | |

Blocktypes are the standard Wasm encoding: `0x40` for an empty result, or a single
valtype byte (`0x6F` for a `lox` result, `0x7F` for `i32`).

Note what is *absent*: no `f64.add`, no `f64.const`. Lox is dynamically typed, so
addition is not `f64.add`; it is a runtime operation that may concatenate strings and
may raise a Lox error. Bolting `f64.*` on would be a lie about what the program means.
Numeric literals are not `f64.const` either, because a `lox` value is not an `f64` — they
live in the constant pool (§4).

## 3. Control flow

Straight out of the Wasm structured control-flow playbook. Lox's grammar is already
reducible, so no relooper is ever needed.

```
if (c) A else B          <c>; call $truthy; if 0x40; <A>; else; <B>; end

while (c) B              block 0x40
                           loop 0x40
                             <c>; call $truthy; i32.eqz; br_if 1   ;; -> block end
                             <B>
                             br 0                                  ;; -> loop head
                           end
                         end

for (I; c; N) B          <I>
                         block 0x40
                           loop 0x40
                             <c>; call $truthy; i32.eqz; br_if 1
                             <B>
                             <N>; drop
                             br 0
                           end
                         end

a and b                  <a>; local.tee $t; call $truthy; if 0x6F; <b>; else; local.get $t; end
a or b                   <a>; local.tee $t; call $truthy; if 0x6F; local.get $t; else; <b>; end
```

`$t` is a compiler-allocated scratch local, just like a real Wasm producer would use.

A Lox function body is a Wasm function body: the result value is whatever is on the
stack at the final `end`, and an early `return e` is `<e>; return`. Falling off the end
of a Lox function yields `nil`, so the compiler emits `global.get $nil_const` before the
final `end`. Falling off the end of an `init` method yields the receiver, so it emits
the code for `this` instead.

## 4. Globals: constants *and* Lox global variables

There is one Wasm global index space, and Vlox puts two kinds of things in it, which is
exactly what a real module would do:

  * **Constants** — every number, string and `nil`/`true`/`false` literal is an
    *immutable* global. Loading a literal is a plain `global.get`. (In a real module
    these are globals with a constant initializer expression, or elements of a data
    segment; either way `global.get` is the load.) Constants are deduplicated.

  * **Lox global variables** — *mutable* globals, one per distinct name, pre-initialized
    to a sentinel `undefined` value.

Lox globals are late-bound: a function may mention a global that is defined later, and
reading a never-defined global is a runtime error naming the variable. So:

```
var x = e;   (top level)     <e>; global.set $x
x            (read)          global.get $x; i32.const $x; call $check_global
x = e        (assign)        <e>; i32.const $x; call $set_global
```

`$check_global` is the identity unless the value is the `undefined` sentinel, in which
case it raises `Undefined variable 'x'.` using the module's global-name table (the
moral equivalent of a Wasm name section). `$set_global` performs the same check before
storing, and leaves the assigned value on the stack, because assignment is an
expression in Lox.

## 5. Locals

Wasm locals, one-to-one. Slot 0 is the callee slot — the closure for a function, the
receiver for a method — which is how clox lays out its frames too, so `this` is just
`local.get 0`. Parameters are slots `1..arity`. Body locals are allocated in declaration
order and never reused across sibling scopes; Wasm locals are free.

Lox closures capture variables *by reference*, and Wasm locals are not addressable. So
the resolver marks every local that some inner function mentions, and those locals are
**boxed**: the slot holds a heap cell instead of the value.

```
var a = e;   (captured)      <e>; call $cell_new; local.set $a
a            (read)          local.get $a; call $cell_get
a = e        (assign)        local.get $a; <e>; call $cell_set
```

A captured *parameter* (or a captured `this`) is boxed by a prologue at function entry:
`local.get $i; call $cell_new; local.set $i`. Because the cell is created by the
executing declaration, a `var` in a loop body correctly produces a fresh binding per
iteration, which is what Lox requires.

Closure creation pushes the captured cells, then the function index and the capture
count:

```
fun f(...) {...}            ;; for each capture, in order:
                              local.get $slot          ;; capture of an enclosing local
                              i32.const $k; call $upvalue   ;; re-capture of an enclosing upvalue
                            i32.const $funcidx
                            i32.const $ncaptures
                            call $closure
```

Inside the closure, `i32.const k; call $upvalue` yields cell `k`, and `$cell_get` /
`$cell_set` read and write it. Upvalue access is therefore two composable intrinsics
rather than a special opcode family.

## 6. Calls

Lox calls are dynamic: the callee is an arbitrary value that must turn out to be a
closure, a class or a native. Vlox spells this

```
f(a, b)                     <f>; <a>; <b>; i32.const 2; call $call
```

`$call` pops the argument count, then that many arguments, then the callee. In a real
Wasm module this expands to an arity check plus `call_indirect` on the closure's code
pointer, with the closure passed as the environment argument; the shape is
deliberately chosen so that expansion is mechanical.

Method calls get the usual fused form so that no bound-method object is allocated:

```
o.m(a, b)                   <o>; <a>; <b>; i32.const $name; i32.const 2; call $invoke
super.m(a)                  local.get 0; <a>; <super cell>; i32.const $name; i32.const 1; call $invoke_super
```

## 7. Objects and dispatch

The high-level object operations. Each is a call to one intrinsic, each has an obvious
function body, and none of them needs a private opcode:

```
o.f                         <o>; i32.const $name; call $get_field
o.f = v                     <o>; <v>; i32.const $name; call $set_field
class C < S { m() {} }      i32.const $name; call $class
                            <S>; call $inherit
                            <closure m>; i32.const $name_m; call $method
super.m                     local.get 0; <super>; i32.const $name; call $get_super
```

`$class`, `$method` and `$inherit` all leave the class on the stack, so a class
declaration is a single expression that ends with a `global.set`/`local.set`.

## 8. The intrinsic table

Function indices `0 .. NUM_INTRINSICS-1`. User functions start at `NUM_INTRINSICS`,
with the top-level script at `NUM_INTRINSICS + 0`. Stack effects are written
`[params] -> [results]`, leftmost = deepest.

| idx | name             | signature                          |
|-----|------------------|------------------------------------|
| 0   | `truthy`         | `[lox] -> [i32]`                   |
| 1   | `not`            | `[lox] -> [lox]`                   |
| 2   | `neg`            | `[lox] -> [lox]`                   |
| 3   | `add`            | `[lox lox] -> [lox]`               |
| 4   | `sub`            | `[lox lox] -> [lox]`               |
| 5   | `mul`            | `[lox lox] -> [lox]`               |
| 6   | `div`            | `[lox lox] -> [lox]`               |
| 7   | `eq`             | `[lox lox] -> [lox]`               |
| 8   | `ne`             | `[lox lox] -> [lox]`               |
| 9   | `lt`             | `[lox lox] -> [lox]`               |
| 10  | `le`             | `[lox lox] -> [lox]`               |
| 11  | `gt`             | `[lox lox] -> [lox]`               |
| 12  | `ge`             | `[lox lox] -> [lox]`               |
| 13  | `print`          | `[lox] -> []`                      |
| 14  | `call`           | `[lox lox* i32] -> [lox]`          |
| 15  | `check_global`   | `[lox i32] -> [lox]`               |
| 16  | `set_global`     | `[lox i32] -> [lox]`               |
| 17  | `cell_new`       | `[lox] -> [lox]`                   |
| 18  | `cell_get`       | `[lox] -> [lox]`                   |
| 19  | `cell_set`       | `[lox lox] -> [lox]`               |
| 20  | `upvalue`        | `[i32] -> [lox]`                   |
| 21  | `closure`        | `[lox* i32 i32] -> [lox]`          |
| 22  | `get_field`      | `[lox i32] -> [lox]`               |
| 23  | `set_field`      | `[lox lox i32] -> [lox]`           |
| 24  | `invoke`         | `[lox lox* i32 i32] -> [lox]`      |
| 25  | `class`          | `[i32] -> [lox]`                   |
| 26  | `inherit`        | `[lox lox] -> [lox]`               |
| 27  | `method`         | `[lox lox i32] -> [lox]`           |
| 28  | `get_super`      | `[lox lox i32] -> [lox]`           |
| 29  | `invoke_super`   | `[lox lox* lox i32 i32] -> [lox]`  |

The five variadic ones (`call`, `closure`, `invoke`, `invoke_super`) are variadic only
in the interpreter, where the Wasm value stack *is* the Lox stack. In a real module the
arguments live in the shadow stack in linear memory (or are passed through
`call_indirect`), and the intrinsic's Wasm signature is fixed.

## 9. What is deliberately not clox

* No `OP_POP` / `OP_POPN` for scope exit — Wasm locals do not live on the value stack,
  so leaving a scope emits nothing at all.
* No `OP_JUMP` / `OP_LOOP` with patched 16-bit offsets — structured `block`/`loop`/`br`
  needs no backpatching and has no 65535-byte loop limit.
* No `OP_CLOSE_UPVALUE` and no open-upvalue list — capture analysis happens in the
  resolver, so captured variables are boxed from birth.
* No per-chunk 256-entry constant pool — one module-wide pool with LEB128 indices.
* No `OP_GET_LOCAL` byte-indexed slots capped at 256 — LEB128 local indices.

Consequently the five `test/limit/` tests that assert clox's specific limits do not
apply; see `test/README.md`. The two limits that are part of the *language* (255
parameters, 255 arguments) are enforced.
