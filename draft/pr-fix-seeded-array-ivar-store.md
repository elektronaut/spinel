title: An array of another kind converts into a seed-pinned array ivar

Fixes #N.

In the reproducer, `fill` is only ever called with the empty `[]` default, because the only caller is `Recording#initialize`'s bare `super`. So inference types its result a general `sp_PolyArray *`, not a boxed value. Without a seed, `@storage` would widen to match; a true `--rbs` seed (`@storage: Array[Integer]`) keeps it an `sp_IntArray *`. The ivar store converts a mismatched value only when it is boxed (`comp_ntype == TY_POLY`, the #4424 path that reads it back through `sp_poly_as_*_array`). A value typed as another array kind went in as a raw pointer, and the C failed to build with an `sp_IntArray *` from `sp_PolyArray *` assignment. The value-position `@x = v` and the statement and value-position `@x ||= v` stores had the same gap; the `||=` form failed the same way on master.

A new `emit_array_store_value` (`src/codegen.c`, declared in `codegen_internal.h`) converts the value when `seeded_array_kind_mismatch` says the slot is an Int, Float or Str array and the value is another array kind (general, Int, Float or Str): it boxes the value and reads it back through the slot's `sp_poly_as_*_array` entry, the same conversion a boxed value already gets. It is used at all four sites: the statement and value-position `@x = v` (`src/codegen_stmt.c`, `src/codegen_expr.c`) and the statement and value-position `@x ||= v`. When the kinds match, or the slot isn't one of those three array kinds, it emits the value exactly as before. Without a seed the slot widens instead of mismatching, so unseeded programs don't reach the new conversion.

Tests: `test/rbs-seed/seeded_array_store_kind.rb` (seed in `test/rbs-seed/sig/seeded_array_store_kind.rbs`) is the issue's reproducer, and covers the plain store reached through a subclass's bare `super`, a value-position store, and `@lazy ||= fill([])`. It is added to the `rbs-seed-test` list in the `Makefile`. It fails on master and matches CRuby 4.0 with this change. `make gate` is clean apart from the two known sandbox failures, `pkg.tmpdir.tmpdir_expand_usable` and `socket_ipv6_and_class_methods`.

Not covered: only Int, Float and Str array slots convert. A seeded object-array slot (`Array[Foo]`) meeting a general Array wasn't tried.

The `fix-seeded-array-ivar-replace` PR (#N) adds its test to the same `rbs-seed-test` line of the `Makefile`, so whichever merges second has a one-line conflict there; keep both names.

This was found in the badline C64 emulator built with an RBS seed that pins its memory `@storage` to `Array[Integer]`, where a recording subclass calls the memory class's constructor through a bare `super`; the reproducer is that shape reduced.
