status: open
branch: fix-redefined-toplevel-def

# redefined-def (handle: umber-wagtail, plus sable-lark)

## umber-wagtail: a redefined top-level method resolves to its first definition

`comp_method_index_direct` returns the first top-level scope with the name, so
calls bind to the first `def`. With different arities it raises ArgumentError
(`redef.rb`); with the same arity it fails the C build with a redefinition
(`redef_same_arity.rb`). CRuby: the last definition wins. Class bodies may have
the same problem; check `def` redefinition inside a class too.

- `21-redefined-def/redef.rb`, `21-redefined-def/redef_same_arity.rb`

## sable-lark: the inlined yield path has no arity check

Do this after umber-wagtail. `emit_inline_call_x` (`src/codegen_iter.c`) binds
a yielding method's parameters with only the unknown-keyword check, so
`y1 { }` on `def y1(x)` runs with `x` padded and `y(1, 2) { }` on
`def y(x, k: 1)` drops the 2. The brief-06 session found that calling
`emit_call_arity_check(c, m, argc, argv, 1)` (skipping the `fwd_encl` case)
before `emit_unknown_kwarg_raise` fixes both, but the gate then failed
`test/builtins_take_drop_while.rb`, which redefines `tw` and only passed
because of umber-wagtail. Separate branch: `fix-inline-yield-arity`.

- `21-redefined-def/yield_arity.rb`
