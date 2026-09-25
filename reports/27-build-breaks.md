# build-breaks (bleak-thrasher + olive-nightjar): report

**Status:** done. Two root causes, two branches, both based on upstream/master `e25c617d`.

| bug | branch | commit |
|---|---|---|
| bleak-thrasher | `fix-build-breaks-write-arg` | `994c1bdffdc2e5f44a3a81d481980fa57a52559d` |
| olive-nightjar | `fix-build-breaks-zero-arg-pf` | `9ee774894c418d7ec35aaf6ac0782d5b401d83a1` |

## bleak-thrasher: `show(buf = +"abc")`

**Root cause.** The analyzer types `show`'s parameter from the argument node.
For a write node, that's the local's own type, TY_STRBUF (a plain read
`show(buf)` gives String). So `s` became a non-shared `sp_String *` parameter.
Codegen renders the write through its String value form, though. The
argument-sequencing hoist in `emit_args_filled` declared `const char * _t1 =
<write>` and handed `_t1` to the `sp_String *` slot. The fix adds
`emit_strbuf_local_write_handle` (codegen_fold.c). For a write to a
STRBUF local, it runs the write as a statement (`emit_assign`) and yields the
local's handle. The hoist uses it for a STRBUF parameter, as does the argument arm (a
hoisted write resolves to its temp). The parameter and the local are one object,
as in Ruby: a mutation inside the callee shows through the caller's local (test
case 2).

**Independent of brief 14.** The write's *expression* form is also broken on
master for a STRBUF local; `fix-array-new-block-string-local` fixes that. This
branch doesn't go through that form, so it works without that branch. The two
branches touch different files.

**Not fixed (pre-existing, also on master):** a method that *returns* its
STRBUF parameter hands back a copy, so aliasing through the return value is lost:
```ruby
class Box; def put(s) = (s << "#"; s); end
u = +"box"; v = Box.new.put(u); u << "~"
p [v, u]     # CRuby ["box#~", "box#~"], spinel ["box#", "box#~"]
```

```
 src/codegen_fold.c                   | 39 ++++++++++++++++++++++++++++++++
 test/strbuf_write_as_arg.rb          | 43 ++++++++++++++++++++++++++++++++++++
 test/strbuf_write_as_arg.rb.expected |  4 ++++
 3 files changed, 86 insertions(+)
```
Test cases: the brief's shape, a callee that mutates the parameter, two
side-effecting arguments in order, and a receiver call. Master gives 13 C errors on this file.

## olive-nightjar: zero-argument poly call into a yielding method

**Root cause: not the proc-form emitter.** `make_yield_proc_forms` already
sets an unknown clone parameter to POLY. The re-narrow reset in the fixpoint
(analyze.c, "clears poly params") then sets every POLY parameter back to UNKNOWN
each round, sparing only block params and `poly_dispatch_widened`. A clone's
parameters are bound by no call site, so nothing widened them again. A clone
reached only by a zero-argument call ended the fixpoint UNKNOWN, and
`emit_proc_call_args` treated the argument as nil/unknown (`sp_int _t1 = lv_x`
from an `sp_RbVal`). The fix sets `poly_dispatch_widened` when the clone's
parameter is made POLY. The field's own comment describes this case: the value
arrives boxed and must survive the reset.

**Second bug, needed for the brief's expected output (also on master, with or
without a block):** a zero-argument poly call reaching a class whose method needs
arguments raised **NoMethodError** instead of ArgumentError. The zero-argument
dispatch emitted arms only for `nrequired == 0` methods; the n-argument
dispatch already emits the ArgumentError case. The zero-argument path now does
the same, with the text from `poly_arm_count` (`expected 1`, `1..2`, `1+`).

**Surprising: the gate caught a regression in my first version.** Boxed scalars
carry `cls_id` 0, so user class 0's new ArgumentError case caught
`pick("abc").sum` in `poly_builtin_default_reentry`. The switch already has a
guarded key for this (`cls0_cand` → `emit_poly_dispatch_key`), but it counted
class 0 only for `nrequired == 0` methods and readers. It now also counts class 0
when it gets the ArgumentError arm.

```
 src/analyze.c                           |  8 ++++--
 src/codegen_call.c                      | 19 +++++++++++-
 test/poly_zero_arg_yield_pf.rb          | 51 +++++++++++++++++++++++++++++++++
 test/poly_zero_arg_yield_pf.rb.expected |  8 ++++++
 4 files changed, 83 insertions(+), 3 deletions(-)
```
Test cases: the brief's shape, optional and rest parameters (message wording),
and the no-block zero-argument case.

## Gates (`make -k -j4 gate TEST_JOBS=-j4`, LANG=C.UTF-8)

bleak-thrasher: `Tests: 4010 pass, 2 fail, 0 error`. olive-nightjar (re-run after
the fix above): `Tests: 4010 pass, 2 fail, 0 error`. On both branches:
```
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
