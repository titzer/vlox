# Imported reference test suite

These tests come verbatim from
[munificent/craftinginterpreters](https://github.com/munificent/craftinginterpreters),
the repository for Robert Nystrom's *Crafting Interpreters*. They are used under
the MIT license in `LICENSE`; do not edit them, so that they keep measuring
conformance against the reference implementations.

Omitted from the import:

- `scanning/` and `expressions/` — chapter-specific debug output that no finished
  implementation produces (the reference `clox` suite skips them too).
- `benchmark/` — no expectations to check.

`SKIP` lists the individual tests that assert clox chunk-format limits Vlox does
not have; see `../README.md`.
