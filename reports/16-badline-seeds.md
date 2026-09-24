# 16-badline-seeds

The two bugs have two separate root causes, so there are two branches, both
from upstream/master `5e6a2e1c`. Both need a true `--rbs` seed that pins an
`Array[Integer]` ivar: the seed stops the slot from widening, and the paths
below had assumed it always could.

## inky-linnet: `fix-seeded-array-ivar-replace`

- Commit `ad67f50aae47777b1f17d4323c286287c43662b2`
  "replace on a seed-pinned typed array converts a source of another kind"
- Diff stat:

```
 Makefile                                         |  2 +-
 src/codegen_call_recv.c                          | 20 +++++++++++
 test/rbs-seed/seeded_array_replace_kind.expected |  4 +++
 test/rbs-seed/seeded_array_replace_kind.rb       | 44 ++++++++++++++++++++++++
 test/rbs-seed/sig/seeded_array_replace_kind.rbs  |  3 ++
 5 files changed, 72 insertions(+), 1 deletion(-)
```

**Root cause.** The typed-array `replace` arm fired only when the source had
the receiver's own kind (`a0 == rt`). Without a seed, the mutation widens the
receiver to a general Array, so a source of another kind never reaches this
arm. With the seed, `@storage` stays an IntArray while `fill(...)` is boxed,
no arm matched, and the call fell through to the NoMethodError gate.

**Fix.** A new arm handles an Int, Float or Str array receiver whose source
is boxed or another array kind. It converts the source through
`sp_poly_as_*_array` and then replaces. A nil or non-Array source raises
TypeError, as in Ruby.

**Test.** `test/rbs-seed/seeded_array_replace_kind.rb` covers value and
statement position, a longer source, and a nil source. It is added to the
`rbs-seed-test` list, which compiles with `-Werror=incompatible-pointer-types`.

## mulberry-fieldfare: `fix-seeded-array-ivar-store`

- Commit `ef93ad2f20f0defd326f2337935f7493fa641df7`
  "An array of another kind converts into a seed-pinned array ivar"
- Diff stat:

```
 Makefile                                       |  2 +-
 src/codegen.c                                  | 21 +++++++++++++++
 src/codegen_expr.c                             |  7 ++++-
 src/codegen_internal.h                         |  2 ++
 src/codegen_stmt.c                             | 11 +++++++-
 test/rbs-seed/seeded_array_store_kind.expected |  4 +++
 test/rbs-seed/seeded_array_store_kind.rb       | 37 ++++++++++++++++++++++++++
 test/rbs-seed/sig/seeded_array_store_kind.rbs  |  4 +++
 8 files changed, 85 insertions(+), 3 deletions(-)
```

**Root cause.** `fill` is only ever given the empty `[]` default, through the
subclass's bare `super`. So inference types its result a typed
`sp_PolyArray*`, not a boxed value. The ivar store converted only a boxed RHS
(`comp_ntype == TY_POLY`). A typed array of another kind went in as a raw
pointer, and the C failed to build with IntArray from PolyArray.

**Fix.** `emit_array_store_value` converts the value when the slot is an
Int, Float or Str array and the RHS is another array kind: it boxes the value
and reads it back through `sp_poly_as_*_array`, which is the #4424 path.
Three sibling sites had the same gap, so it is used at all four: the
statement and value-position `@x = v`, and the statement and value-position
`@x ||= v`. I confirmed the `||=` form failed the same way before the fix.

**Test.** `test/rbs-seed/seeded_array_store_kind.rb` covers the plain store
via bare `super`, a value-position store, and `||=`. It is added to the
`rbs-seed-test` list.

## Gate (each branch, LANG=C.UTF-8)

The results were identical on both branches:

```
Tests: 4005 pass, 2 fail, 0 error
FAIL: pkg.tmpdir.tmpdir_expand_usable   (known: root)
FAIL: socket_ipv6_and_class_methods     (known: no UDP)
Benchmarks: 62 pass, 0 fail, 0 error, 0 skip
Optcarrot: OK
infer-test: pass
rbs-seed-test: pass
spin-e2e: ALL GREEN
rubyspec-gate[language]: all 671 expected-PASS examples still pass
rubyspec-gate[core/array]: all 421 expected-PASS examples still pass
rubyspec-gate[core/string]: all 571 expected-PASS examples still pass
rubyspec-gate[core/hash]: all 192 expected-PASS examples still pass
rubyspec-gate[core/integer]: all 171 expected-PASS examples still pass
rubyspec-gate[core/range]: all 83 expected-PASS examples still pass
```

## Notes

- **Makefile conflict.** Both branches append their test to the same
  `for t in ...` line of the `rbs-seed-test` recipe in the Makefile. Whichever
  merges second will conflict there. The resolution is to keep both names.
- **Scope.** The conversion covers only Int, Float and Str array slots. A
  seeded object-array (`Array[Foo]`) slot meeting a general Array was not
  tried.
- **Building by hand.** To build generated C by hand here, add `-lcrypt` to
  the link line.
