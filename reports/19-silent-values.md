# silent-values (rusty-nuthatch + dun-shoveler): report

**Status:** done — two root causes, two branches, both based on upstream/master `5e6a2e1c`.

| bug | branch | commit |
|---|---|---|
| rusty-nuthatch | `fix-silent-wrong-values-struct-splat` | `4bdff7a9360ddf117f8c20ed7b75eff523f7b498` |
| dun-shoveler | `fix-silent-wrong-values-puts-to-s` | `2f360d2d0451f946cfff5493a7f1e2ac5618d138` |

## rusty-nuthatch: `S.new(*args)` member types

**Root cause.** `struct_new_types_members` (analyze_pass.c) read a `SplatNode`
as one positional argument. With `S.new(*args)`, member 0 took the splat node's
type and the rest took nil, while another site's `S.new(1, 2)` typed both
members Integer. The splat path then unboxed a String element as an int
(garbage) and the nil fill as 0. Now a member at or past the splat unifies to
POLY: it gets a run-time element or a nil fill.

**Surprising 1.** My first version typed those members as "splat element type ∪
nil". The gate's `issue_2971` caught that: `S.new(*[1])` gave `[1, 0]`, because
Integer ∪ nil stays a plain Integer slot and the nil fill unboxes as 0. That's why
the fix boxes the member instead of unifying types.

**Surprising 2: a sibling that failed to compile on master.** Positionals beside
a splat, as in `S.new(0, *rest)` and `S.new(*mid, "end")`, produced invalid C:
`incompatible types when assigning to type 'sp_RbVal' from type 'sp_PolyArray *'`.
Only a *sole* splat reached `emit_struct_splat_new`. That emitter is now split:
`emit_struct_spread_new` spreads an array expression across the members, with the
existing Data exact-count and Struct "struct size differs" checks. The new
`emit_struct_mixed_splat_new` gathers all positionals and splats into one
PolyArray, in order, and hands it over. ArgumentError for an overlong Struct or a
short Data still matches CRuby.

```
 src/analyze_pass.c                        | 14 ++++++++++
 src/codegen_call.c                        | 45 +++++++++++++++++++++++++++++--
 test/struct_new_splat_members.rb          | 30 +++++++++++++++++++++
 test/struct_new_splat_members.rb.expected |  9 +++++++
 4 files changed, 96 insertions(+), 2 deletions(-)
```

The test covers the brief's shapes, a short Integer-array splat, a leading
positional plus splat, a splat plus trailing positional, and a two-member Data
splat.

## dun-shoveler: `puts` on a boxed value-type object

**Root cause.** The runtime renders a boxed object through the generated
`sp_obj_to_s_sw` / `sp_obj_inspect_sw` dispatchers (codegen.c). Both skipped
value-type classes (`comp_ty_value_obj`), and so did their forward
declarations. A boxed value object therefore fell to `#<A:0x…>` for `puts obj`
and `"#{obj}"`. The inline poly dispatch that `obj.to_s` uses already called
`sp_A_to_s(*(sp_A *)p)`, which is why `v.to_s` was right. Value types now get
arms in the same by-value form, for a user `#to_s` and a user `#inspect`.

**Sibling fixed.** `p obj` on a boxed value object with a user `#inspect`
printed `#<Object>`. Without a user `#inspect`, a value type still falls to the
existing default; that dispatcher's "no stable address" rule is unchanged.

```
 src/codegen.c                         | 36 +++++++++++++++++++++++++++++------
 test/value_obj_boxed_to_s.rb          | 28 +++++++++++++++++++++++++++
 test/value_obj_boxed_to_s.rb.expected |  6 ++++++
 3 files changed, 64 insertions(+), 6 deletions(-)
```

The test covers `puts`, interpolation, `to_s +` concatenation, `p` with a user
`#inspect`, and a class with no `to_s`. I checked in the C that the objects
really are value types (`sp_box_vobj`). The arms only cover a method the class
defines itself (`tdef == i`); an inherited `to_s` on a value type isn't
covered, and I didn't find a program that makes such a class a value type.

## Gates (`make -k -j4 gate TEST_JOBS=-j4`, LANG=C.UTF-8), identical on both branches

```
Tests: 4006 pass, 2 fail, 0 error
  FAIL: pkg.tmpdir.tmpdir_expand_usable      (known: root in container)
  FAIL: socket_ipv6_and_class_methods        (known: no UDP in sandbox)
Benchmarks: 62 pass, 0 fail, 0 error, 0 skip
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
