# operand-order: report

**Status:** done. Two root causes, two branches, both based on upstream/master `5e6a2e1c`.

| bug | branch | commit |
|---|---|---|
| jade-stoat | `fix-poly-array-op-assign` | `f8fdb242b1e2e0a2f7841bb185a7bf735ceacf9b`: "An op-assign on a poly array boxes a typed-array rhs" |
| birch-raven | `fix-poly-array-op-assign-recv-order` | `ed9db752d0e7dffec787ad35c8c3283dac015bed`: "A call reads a global, ivar or cvar receiver before its arguments run" |

## jade-stoat: poly Array op-assign with a different-kind rhs

**Root cause.** `emit_array_op_assign` (`codegen_stmt.c`) is shared by
local, ivar, global and cvar slots. It required the rhs of `-=` `|=` `&=`
`+=` to be the slot's own array kind. The binary `poly_array OP typed_array`
arms (`codegen_call_recv.c`) box the typed operand into a PolyArray first
(`sp_IntArray_to_poly` / `sp_StrArray_to_poly_fmt` / `sp_FloatArray_to_poly`,
plus `sp_poly_set_operand` for a boxed rhs), but the op-assign never got those
arms. So a local was refused, and a global or ivar fell through to raw C `-`
between two array pointers, which didn't compile. The brief's file only showed
the first refusal.

**Fix.** A `poly_array_rhs_conv` helper applies the binary path's conversions
in the set-op and `+` arms, and only when the slot is a PolyArray.

```
 src/codegen_stmt.c                          | 24 +++++++++++++++++---
 test/poly_array_op_assign_mixed.rb          | 35 +++++++++++++++++++++++++++++
 test/poly_array_op_assign_mixed.rb.expected | 10 +++++++++
 3 files changed, 66 insertions(+), 3 deletions(-)
```

The test covers the brief's three slot kinds, `+=` / `|=` / `&=` / `-=`
with Integer, String and Float rhs arrays, and a boxed rhs holding an array.
It's refused on unpatched master.

**Deferred (same family, different cause):** a *typed* slot with a
different-kind rhs is still refused, for example `m = [1, 2]; m -= ["x"]` or
`m = ["a"]; m |= [1]`. The binary spelling `m = m | [1]` works because
inference widens the local to poly on that write. The op-assign's inferred
type (`analyze_infer.c`, `NK_LocalVariableOperatorWriteNode`: "ct2 != UNKNOWN
? ct2 : vt2") keeps the slot's kind, so no widening happens. That needs an
inference change for all slot kinds, so I left it out. It's a loud refusal,
not a miscompile.

## birch-raven: receiver read after the argument's prelude

**Root cause.** The builtin arms emit the receiver inline (`gv_a`) and hoist
the arguments' preludes into `g_pre` ahead of the statement. So `$a + [replace]`
ran `replace` (which reassigns `$a`) and only then read `$a`. This isn't
specific to one arm: `+`, `union`, `|`, String `+`, `-`, `==`, `include?` and
Integer `+` all did it. In the brief, the `include?` row passed only because
its answer is `false` either way.

**Fix.** It's done once, in `emit_call_held` (`codegen_call.c`), ahead of all
arms. Three conditions:
- the receiver is a Global/Instance/ClassVariableReadNode of a typed
  non-object value,
- the call has no block,
- the method is on a whitelist of operators and queries that don't mutate
  the receiver (`+ - * / % ** | & ^ == != < > <= >= <=> union difference
  intersection intersect? include? member? eql?`).

If any argument `subtree_has_side_effect`, the slot is read into a rooted
temp in `g_pre` and registered in the existing `g_argov_*` override table,
so every arm reads the temp. Mutators are deliberately left out because an
arm may write the slot back through the same node. `$x.push(gx)` was already
right and still is.

```
 src/codegen_call.c                     | 50 +++++++++++++++++++++++++++
 test/recv_read_before_args.rb          | 63 ++++++++++++++++++++++++++++++++++
 test/recv_read_before_args.rb.expected | 13 +++++++
 3 files changed, 126 insertions(+)
```

The test is the brief's reproducer plus variants: an ivar receiver with `+`
and `include?` (true vs false), a cvar receiver with `-`, a String global with
`==`, an Integer global with `+`, and `$x.push(gx)` as a mutator control.
Master (the jade-stoat build, which has no receiver-order change) gets 9 of the 13 lines wrong.

**Not covered:** a *local* captured by a proc that the argument calls
(`a = [1]; f = -> { a = [2]; 3 }; a + [f.call]`), and user-object receivers
(left to their own dispatch paths).

## Gates (`LANG=C.UTF-8 make -k -j4 gate TEST_JOBS=-j4`, each branch)

Both runs:
```
Tests: 4006 pass, 2 fail, 0 error     (tmpdir_expand_usable: root; socket_ipv6_and_class_methods: no UDP)
Optcarrot: OK
infer-test: pass
spin-e2e: ALL GREEN
rubyspec-gate[language]: all 671 expected-PASS examples still pass
rubyspec-gate[core/array]: all 421 expected-PASS examples still pass
rubyspec-gate[core/string]: all 571 expected-PASS examples still pass
rubyspec-gate[core/hash]: all 192 expected-PASS examples still pass
rubyspec-gate[core/integer]: all 171 expected-PASS examples still pass
rubyspec-gate[core/range]: all 83 expected-PASS examples still pass
```
Benchmarks: 62 pass for jade-stoat. For birch-raven the gate run showed
6 ERRs (the first six alphabetically) while a parallel build was loading the
machine. A standalone `make bench` right after gave `62 pass, 0 fail, 0 error`.

## Surprising: a separate runtime bug found along the way

PolyArray set ops compare Integer and Float with `==` instead of `eql?`, on
master and in the binary form too:
`[1, 2, "y"] - [2.0]` gives `[1, "y"]` (CRuby `[1, 2, "y"]`),
`| [2.0]` gives `[1, 2, "y"]` (CRuby `[1, 2, "y", 2.0]`), and
`& [2.0]` gives `[2]` (CRuby `[]`). This is a candidate for its own brief. The
cause is likely in the `sp_PolyArray_difference/union/intersect` element
comparison in `lib/`.
