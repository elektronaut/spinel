# 21-redefined-def: report

**Status:** done. Both bugs are fixed on two branches.

| Bug | Branch | Base | Commit |
|---|---|---|---|
| umber-wagtail | `fix-redefined-toplevel-def` | upstream/master `ab41b4ae` | `c0a897316c0584438dea1070e23844ee38f229d1`: "A redefined top-level method is the definition in effect where it is called" |
| sable-lark | `fix-inline-yield-arity` | **`fix-surplus-arg-refusal` (brief 06, `463019f5`)** | `4d38c8ab324dbadddc5588c9b6bb5340a225b890`: "An inlined yielding method judges its call's count and binds a **kwrest" |

Every reproducer in `briefs/21-redefined-def/` matches its `.expected` output (on
the combined tree for sable-lark).

## umber-wagtail (`fix-redefined-toplevel-def`)

**Root cause.** `comp_method_index_direct` returned the first top-level scope with
the name, and the frozen index was built so the lowest index won. So every call
bound to the first `def`. A later def with another arity refused its calls; one
with the same arity was a C redefinition. Classes already worked:
`comp_method_in_class` takes the last def, and `scope_is_shadowed` suppresses the
earlier ones.

Plain "last def wins" isn't CRuby either, and the existing test
`builtins_take_drop_while` catches it. It calls `tw { }` between `def tw(&b)` and
`def tw(a)`, where CRuby runs the first body. So the fix is position-aware:
- **New pass `rename_redefined_toplevel_defs`** (analyze.c, before scopes are
  built). When a bare top-level `def` is redefined by a later one, the earlier def
  gets a private name, `<name>__redef<N>`. The top-level calls that run before the
  redefinition are renamed to it: receiverless calls in the program's statements
  and their blocks. The walk doesn't descend into def, class or module bodies,
  because those run later or with another self. The last def keeps the name, and
  every other call (method bodies) reaches it.
- **Fallback** for a redefinition the pass can't place, such as a def inside an
  `if`: top-level lookup is now last-wins, like a class's, and `scope_is_shadowed`
  covers an earlier top-level `DefNode`, so it isn't emitted.
- `multi_return_elem_types` (analyze_pass.c) had its own first-match scan; it now
  uses `comp_method_index`.

Class bodies: checked as the brief asked. `def` redefinition in a class, and
`def self.x` in a module, already give the last definition; covered in the test.

```
 src/analyze.c                           | 57 +++++++++++++++++++++++++++++++++
 src/analyze_pass.c                      |  5 ++-
 src/codegen_internal.h                  |  5 +--
 src/codegen_util.c                      | 15 ++++++++-
 src/compiler.c                          |  9 ++++--
 test/toplevel_def_redefined.rb          | 45 ++++++++++++++++++++++++++
 test/toplevel_def_redefined.rb.expected | 14 ++++++++
 7 files changed, 141 insertions(+), 9 deletions(-)
```

Gate (`make -k -j4 gate TEST_JOBS=-j4`, LANG=C.UTF-8):
```
Tests: 4009 pass, 2 fail, 0 error
  FAIL: pkg.tmpdir.tmpdir_expand_usable      (known)
  FAIL: socket_ipv6_and_class_methods        (known)
Benchmarks: 62 pass, 0 fail, 0 error, 0 skip
Optcarrot: OK
infer-test: pass
spin-e2e: ALL GREEN   (known push-negotiation warning)
diff-test: pass
rubyspec-gate[language]: all 671 expected-PASS examples still pass
rubyspec-gate[core/array]: all 421 expected-PASS examples still pass
rubyspec-gate[core/string]: all 571 expected-PASS examples still pass
rubyspec-gate[core/hash]: all 192 expected-PASS examples still pass
rubyspec-gate[core/integer]: all 171 expected-PASS examples still pass
rubyspec-gate[core/range]: all 83 expected-PASS examples still pass
```

**Limits, by design:**
- A top-level lambda or proc that calls the method and is invoked after the
  redefinition still reaches the earlier def (the walk treats every block as
  running where it is written).
- `method(:name)` / `send(:name)` between the defs aren't renamed.
- A def inside a conditional gets the fallback: last-wins, where CRuby depends on
  which branch ran.
- `__method__` inside an earlier def answers the private name.

## sable-lark (`fix-inline-yield-arity`)

**Branch base: please read.** The brief's fix calls `emit_call_arity_check`. That
helper exists only on brief 06's `fix-surplus-arg-refusal`, which upstream
hasn't merged. So this branch sits on top of that one: one commit, `4d38c8ab`, on
`463019f5`. That goes against the README's "never base a fix on an earlier fix
branch", but the brief itself sets up the dependency. As the brief predicted, the
branch alone fails `builtins_take_drop_while`, which also needs umber-wagtail. So
I gated it on a local, unpushed merge of `fix-inline-yield-arity` and
`fix-redefined-toplevel-def`. **Merge order: 06, then umber-wagtail, then this.**

**Root cause.** `emit_inline_call_x` (codegen_iter.c) bound a yielding method's
parameters with only the unknown-keyword check. It now calls
`emit_call_arity_check(c, m, argc, argv, 1)` (made non-static), or keeps the
keyword check alone for a `...` forward.

**Sibling fixes in the same binding loop** (the second is also on master):
- A surplus positional was bound into a `**kwrest`'s hash slot:
  `ykw(1, 2) { }` on `def ykw(a, **kw)` failed the C build. Keyword and kwrest
  parameters no longer take a positional.
- A `**kwrest` was never collected on this path, so `kw` read nil
  (`ykw(1, z: 2) { |a, kw| }` gave `[1, nil]`). It now uses
  `emit_kwrest_collect`, made non-static, as the other paths do.

```
 src/codegen_fold.c                  |  7 ++++---
 src/codegen_internal.h              |  4 ++++
 src/codegen_iter.c                  | 27 +++++++++++++++++++++------
 test/inline_yield_arity.rb          | 32 ++++++++++++++++++++++++++++++++
 test/inline_yield_arity.rb.expected | 17 +++++++++++++++++
 5 files changed, 78 insertions(+), 9 deletions(-)
```

Gate, on the local merge of `fix-inline-yield-arity` and
`fix-redefined-toplevel-def`:
```
Tests: 4011 pass, 2 fail, 0 error
  FAIL: pkg.tmpdir.tmpdir_expand_usable      (known)
  FAIL: socket_ipv6_and_class_methods        (known)
Benchmarks: 62 pass, 0 fail, 0 error, 0 skip
Optcarrot: OK
infer-test: pass
spin-e2e: ALL GREEN   (known push-negotiation warning)
diff-test: pass
rubyspec-gate[language]: all 671 expected-PASS examples still pass
rubyspec-gate[core/array]: all 421 expected-PASS examples still pass
rubyspec-gate[core/string]: all 571 expected-PASS examples still pass
rubyspec-gate[core/hash]: all 192 expected-PASS examples still pass
rubyspec-gate[core/integer]: all 171 expected-PASS examples still pass
rubyspec-gate[core/range]: all 83 expected-PASS examples still pass
```

## Merge notes

- **With `fix-rest-default-binding-splat-tail` (brief 07, D):** D changes
  `opt_before_required(m)` to `opt_before_required(c, m)`. 06's
  `emit_call_arity_check`, which this branch carries, calls the one-argument form.
  Whichever lands second updates that call.
