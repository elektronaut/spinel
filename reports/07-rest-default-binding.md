# 07-rest-default-binding: report

**Status:** done. All five bugs are fixed on four branches, one per root cause, each
based on upstream/master `032c037a` with its own test.

| Bug | Branch | Commit |
|---|---|---|
| quartz-wren | `fix-rest-default-binding` | `2d7fa93ef3a7cd667cd99e06c17aa42707f583ee`: "A leading optional binds around a *rest and a **kwrest" |
| ochre-vole, pale-scoter | `fix-rest-default-binding-pd` | `b09ab588e2296022c8b2293e944d6c1fdd28e62e`: "A default reading an earlier parameter binds beside a *rest and a **kwrest" |
| sable-ruff | `fix-rest-default-binding-splat-nil` | `29fea8ae933aaedaddb14d95a92c58cbb690e072`: "*nil spreads to nothing into a rest, and a scalar splat binds as one argument in dispatch" |
| mossy-godwit | `fix-rest-default-binding-splat-tail` | `d531bf5adadd56c76c6d813936148eaa1b0cbcd3`: "A splat with positionals after it binds from them all beside keyword parameters" |

Every reproducer in `briefs/07-rest-default-binding/` matches its `.expected`
output on its branch.

## A: quartz-wren (`fix-rest-default-binding`)

**Root cause.** `arg_slot_for_param` gave up on any method with a `*rest` or
`**kwrest` and fell back to positional mapping. So for `def r(a = {}, *rest, c)`,
`r(5)` bound the 5 to `a` as well as to `c`, and `def kk(a = {}, c, **kw)` left `c`
at 0. The map now skips the rest, which is funded last, and ends the positional
list before the keywords and kwrest.

**Sibling fix, pre-existing on master.** The post-rest branch of `emit_args_filled`
treated every parameter after the rest as a post. So in `def kq(*r, c, k: 0)`,
`kq(1, k: 2)` bound k to the last positional, not to its key. The dispatch path
already had the `i <= rest_idx + npost_rest` bound; the direct path now has it too.

```
 src/codegen_fold.c                          | 24 ++++++++++++++---------
 test/rest_leading_optional_slot.rb          | 32 +++++++++++++++++++++++++++++
 test/rest_leading_optional_slot.rb.expected | 20 ++++++++++++++++++
 3 files changed, 66 insertions(+), 9 deletions(-)
```

## B: ochre-vole + pale-scoter (`fix-rest-default-binding-pd`)

**Root cause.** Both are one bug. The call-site hoist that lets a default read an
earlier parameter was limited to methods with no rest and no kwrest. For
`def m(n, *r, k: n + r.size)` and `def h(x, y = 7, z = x * 2, **kw)` the default
was emitted against `lv_n` / `lv_x`, which nothing declares at the call site, so
the C build failed. The hoist now binds the rest, its posts and the kwrest the way
the plain path does. That applies to all three call paths: `emit_args_filled`,
`emit_dispatch` (instance), and the poly receiver arm in
`emit_poly_method_dispatch`.

The dispatch path packs the rest and kwrest with the parameter renames off, so a
caller local that shares a parameter's name stays the caller's. Before that change,
`o.m(1, n, r)` packed `[1, 20]`, not `[10, 20]`; the test covers it.

**Sibling fixes in the poly receiver arm** (codegen_call.c; on master, the
poly-receiver cases that don't depend on a default misbehave the same way):
- With no keyword hash, a declared keyword took a positional:
  `q.m(3, 1, 2)` on `def m(n, *r, k: ...)` bound k to 2.
- A post after the rest was also chosen by `a > r_idx` without an upper bound.
- A param ahead of the rest could read an argument that belongs to the posts.
- A `**kw` bound nil, not `{}`, when the call passed no keywords.

```
 src/codegen_call.c                                  | 23 +++++--
 src/codegen_fold.c                                  | 64 ++++++++++++++----
 test/default_reads_param_rest_kwrest.rb             | 69 +++++++++++++++++++
 test/default_reads_param_rest_kwrest.rb.expected    | 37 ++++++++++
 4 files changed, 174 insertions(+), 19 deletions(-)
```

## C: sable-ruff (`fix-rest-default-binding-splat-nil`)

**Root cause.** Two gaps in splat lowering:
1. When packing a rest, a statically nil splat operand took the scalar branch and
   went in as one element: `r(*nil)` gave `[nil]`. The same happened in the suffix
   loop of `emit_rest_from_splat_and_argv`, which also pushed a boxed operand whole
   rather than spreading it, and rendered the operand even when that render went
   unused.
2. The instance-dispatch splat layout (`splat_at_d`) lowered only a poly or unknown
   operand through the splat's own normalization, not a nil or scalar one. That is
   the same gap #4898 closed in `emit_args_filled`, so `O.new.m(*7)` bound `[7]`.
   On master `o.g(*5)` on `def g(x) = x + 1` crashed with "no implicit conversion
   of Integer into Array".

A nil operand is still evaluated for side effects; the test covers that with a
method that prints.

```
 src/codegen_fold.c                              | 27 +++++++++++++++++++---
 test/splat_nil_scalar_into_rest.rb              | 36 ++++++++++++++++++++++++
 test/splat_nil_scalar_into_rest.rb.expected     | 14 +++++++++++
 3 files changed, 74 insertions(+), 3 deletions(-)
```

## D: mossy-godwit (`fix-rest-default-binding-splat-tail`)

**Root cause.** A splat followed by more positionals is gathered into one array
and bound from it. matz's f09820a5 did this, but it was refused whenever the callee
had a keyword parameter or the call had a keyword hash. So
`kw(*[1], 2, k: 3)` on `def kw(a, b = 0, k: 1)` took the layout that assumes the
splat fills the gap exactly. The instance-dispatch path had no gather and no
trailing-positional handling at all: `O.new.o(*[1], 3)` dropped the 3, and
`O.new.m(*[1, 2], 3)` raised nothing.

**The fix.**
- Gathering is now a shared helper pair, `splat_gather_applies` and
  `emit_splat_gather`, used by both paths. It allows keyword parameters and a
  keyword hash that binds as keywords.
- A gathered element is unboxed into a typed parameter on the dispatch path.
- The optional guard also checks `pdefault`, because `nrequired` counts a required
  keyword.

**`opt_before_required` fix.** `def rk(a, b = 0, k:)` read as having a leading
optional, because the required keyword bumped `nrequired`. The function now reads
the def's Prism parameters (optionals and posts both present). It falls back to
`nrequired` only for a scope with no def parameter list. This changes its
signature to `opt_before_required(Compiler *c, Scope *m)`.

```
 src/codegen_fold.c                                 | 168 +++++++++++++--------
 src/codegen_internal.h                             |   2 +-
 test/splat_trailing_positional_keywords.rb         |  39 +++++
 .../splat_trailing_positional_keywords.rb.expected |  19 +++
 4 files changed, 168 insertions(+), 60 deletions(-)
```

## Gate (`make -k -j4 gate TEST_JOBS=-j4`, LANG=C.UTF-8), per branch

B, C and D (C and D identical):
```
Tests: 3996 pass, 2 fail, 0 error
  FAIL: pkg.tmpdir.tmpdir_expand_usable      (known: root in container)
  FAIL: socket_ipv6_and_class_methods        (known: no UDP in sandbox)
Benchmarks: 62 pass, 0 fail, 0 error, 0 skip
Optcarrot: OK
infer-test: pass
spin-e2e: ALL GREEN   (with the known "push negotiation failed" warning)
rubyspec-gate[language]: all 671 expected-PASS examples still pass
rubyspec-gate[core/array]: all 421 expected-PASS examples still pass
rubyspec-gate[core/string]: all 571 expected-PASS examples still pass
rubyspec-gate[core/hash]: all 192 expected-PASS examples still pass
rubyspec-gate[core/integer]: all 171 expected-PASS examples still pass
rubyspec-gate[core/range]: all 83 expected-PASS examples still pass
```
A: same rubyspec, optcarrot and props lines, plus two extra items:
```
Tests: 3995 pass, 3 fail, 0 error   (the known two, plus ffi_io_buffer_arg_guards)
Benchmarks: 61 pass, 0 fail, 1 error (bm_ackermann)
```
Neither is caused by the change:
- **`bm_ackermann`:** re-running `make bench` alone gives 62/62. The ERR was the
  10 s compile timeout under the gate's parallel load; this was A's gate, run while
  I was building B, C and D.
- **`ffi_io_buffer_arg_guards`:** a thread-timing test. The main thread frees a
  buffer while another thread is in a blocking FFI call, and the test expects
  LockedError. Under load it printed "freed during the call". It passed six times
  in a row standalone on the same build. Its generated C is byte-identical to
  master's apart from `#line` paths. This looks like a real load-dependent race in
  the runtime lock (the flag `g_started` is set before the lock is visible to the
  other thread?). It is not a binding bug and not in this brief, so I left it
  alone.

## Merge notes

- **A and D both touch the top of `arg_slot_for_param`.** D changes the
  `opt_before_required(m)` call there to `opt_before_required(c, m)`, and A
  rewrites the lines just below it. Expect an adjacent-hunk conflict. Keep both.
- **`fix-poly-arm-arity` (brief 08) and D:** 08 calls `opt_before_required(ms)`,
  so whichever of the two lands second must switch those calls to the
  two-argument form, or the build breaks.
- **`fix-poly-arm-arity` and B:** 08 also makes the poly arm's `**kw` an empty
  hash when there are no keywords. B does the same thing (`if (a == ms->kwrest_idx)`),
  so it's one duplicate line; keep either.
- **A with 08:** 08 routes poly-arm binding through `arg_slot_for_param` when
  `opt_before_required`. With A, that map is also right for rest and kwrest
  methods.

## Surprising / not fixed here

- **Poly-arm arity:** a poly receiver whose method has any post parameter
  (`def f(a, *r, c)`, even `def f(a, b = 1, c)`) had every arm dropped, so the call
  raised NoMethodError. The arm filter reads `nrequired` as a count. I stopped when
  I saw brief 08's report, which fixes exactly this, so there's no branch here.
- **Scope clones don't copy `npost_rest`:** the clone sites in
  `analyze.c` / `analyze_scope.c` copy `nrequired`, `rest_idx` and `kwrest_idx` but
  not `npost_rest`. So a cloned method with posts (proc form, include copy,
  singleton subclass) sees `npost_rest == 0`. I didn't build a reproducer. D avoids
  depending on it by reading the def's parameters instead.
- **No-rest methods with posts:** `npost_rest` is also set for a method with posts
  and no rest (`def f(a = 1, b)`). A reader that assumes it implies a rest could
  misfire, though the sites I read all check `rest_idx >= 0` first.
