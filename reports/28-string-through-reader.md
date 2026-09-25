# string-through-reader: report

**Status:** done. Both handles (gray-shearwater, tan-longspur) are fixed on one
branch, because they share one area: how an ivar handle is shared through its
reader.

**Branch:** `fix-string-mutation-through-reader` (on origin, based on upstream/master `e25c617d`)
**Commit:** `cddf4ffc861082665861d80d0b07cf6cc7ee9aca`: "A String ivar mutated through its reader is the same object everywhere"

Upstream has since moved to `05a3fc37`, which includes "Stores into a container
local", a commit in the same string-handle analysis. The commit merges
cleanly onto it. In a scratch tree I built the cherry-pick on `05a3fc37`
and ran both new tests plus 150 existing string/strbuf/attr_reader tests: all
pass, apart from two that my ad-hoc harness can't run (`argv_gc` needs its
`.args`; `builtin_arity_reach`). Both fail the same way on the gated build,
where the real gate passed them. The full gate below ran on `e25c617d`.

## Root causes

Three gaps. Each one let a mutation through `obj.reader` land in a copy:

1. **gray-shearwater (alias).** The reader-alias pass (#3227 P5,
   `x = c.name`) only shared the handle when the ivar's *own class* mutates
   it (`strbuf_ivar_mut_kind == 1`). When the only mutation is through the
   reader, the ivar was already a shared handle (the external reader-mutation
   pass had promoted it), but the alias was still emitted as a copy. Fix: the
   alias pass also accepts an ivar that is already a shared handle.
2. **tan-longspur (slice! / []= / insert / setbyte through a reader).** The
   external reader-mutation pass only took the mutators with an ivar arm
   (`SP_MUT_IVAR`). So `c.name.slice!(0)` was silently dropped, and
   `c.name[0] = "X"` raised `NoMethodError` at run time (on master, even
   without an alias). Fix: the pass takes every mutator. Codegen then runs the
   #4363 shared-mutable shim over the reader call: the call is overridden to
   read the shadow (`sb_call_shadow_open/close`, via the `g_argov_*` override
   table), typed as a plain String, and marked as an lvalue (`g_sb_shadow_recv`)
   for the arms' write-back checks. Afterwards the shadow is written back
   with `sp_String_set_bin`. This works in statement and value position.
   Inference needed one change too: a handle-marked receiver (TY_STRBUF)
   matched none of the String rows, so `setbyte`'s Integer answer was typed as
   a String. `infer_call` now treats it as a String receiver, except for the
   self-returning appenders (`<<`, `concat`, `prepend`, `replace`, `insert`,
   `clear`). Those keep the handle type, because the in-place append arm is
   chosen on it. Without that exception, `issue_3307_container_reader_mutation`
   regressed during the first gate run.
3. **The setbyte variant.** `insert`, `slice!`, `[]=` or `setbyte` on the
   ivar *inside its class* marked the ivar -1 (never promote). That predates
   the #4363 ivar shims, which now handle all four. Once an ivar was marked,
   even a plain `c.name << "!"` through its reader was silently lost. Fix:
   those four count as ordinary mutators (1).

## Tests

- `test/string_ivar_reader_alias.rb`: the brief's `alias_mutation.rb`, plus
  an alias surviving `[]=` and `upcase!` through the reader, a mutation of the
  alias itself reaching the ivar, and `insert` with `equal?` identity.
- `test/string_ivar_reader_mutators.rb`: the brief's `slice_bang.rb`, plus
  all four mutators through the reader in value and statement position, the
  same four *inside* the class followed by `<<` and an alias through the reader
  (the setbyte variant), and FrozenError through the reader.

Each section is in its own method so its receivers stay monomorphic (see below).
Both files fail on unpatched upstream.

## Diff stat

```
 src/analyze.c                                | 28 +++++++---
 src/analyze_infer.c                          | 10 ++++
 src/codegen_call_recv.c                      | 62 ++++++++++++++-------
 src/codegen_internal.h                       |  9 ++++
 src/codegen_stmt.c                           | 40 ++++++++++++--
 src/codegen_util.c                           | 20 +++++++
 test/string_ivar_reader_alias.rb             | 39 ++++++++++++++
 test/string_ivar_reader_alias.rb.expected    |  9 ++++
 test/string_ivar_reader_mutators.rb          | 81 ++++++++++++++++++++++++++++
 test/string_ivar_reader_mutators.rb.expected | 17 ++++++
 10 files changed, 285 insertions(+), 30 deletions(-)
```

## Gate (`LANG=C.UTF-8 make -k -j4 gate TEST_JOBS=-j4`, final tree)

```
Tests: 4011 pass, 2 fail, 0 error     (tmpdir_expand_usable: root; socket_ipv6_and_class_methods: no UDP)
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

## Not fixed: poly receiver through a reader

When the reader's receiver is poly (one local holding objects of two classes
that both define `name`), a mutation through the reader doesn't compile:
`assignment to 'sp_String *' from incompatible pointer type 'const char *'`
in the poly dispatch. This already happens on master with plain `<<`:

```ruby
class A; attr_reader :name; def initialize = @name = +"ab"; end
class B; attr_reader :name; def initialize = @name = +"cd"; end
c = A.new; c.name << "!"; p c.name
c = B.new; c.name << "?"; p c.name       # CRuby "ab!" / "cd?"
```

On master, `c.name[0] = "X"` in that shape raised NoMethodError at run time.
With this branch it's the same C compile error as `<<`. The poly reader
dispatch (`sp_pd_*`) types its result slot `const char *` while the handle
demand assigns an `sp_String *`. That's a candidate for its own brief.
