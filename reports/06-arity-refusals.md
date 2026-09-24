# 06-arity-refusals

All three bugs (mossy-lynx, willow-bison, violet-mole) share one root cause
and are fixed on one branch.

- Branch: `fix-surplus-arg-refusal`
- Commit: `3c13f2b425a6de4b9238db35d77fdb9823e8d95c`
  "A surplus positional into a keyword or **kw callee raises ArgumentError"
- Diff stat (vs upstream/master 032c037a):

```
 src/codegen_fold.c                   | 242 ++++++++++++++++++++---------------
 src/codegen_internal.h               |   1 +
 test/surplus_arg_refusal.rb          |  50 ++++++++
 test/surplus_arg_refusal.rb.expected |  17 +++
 4 files changed, 207 insertions(+), 103 deletions(-)
```

## Root cause

The direct-call arity check in `emit_args_filled` (`src/codegen_fold.c`)
had three problems:

1. It counted declared keyword parameters as positional slots, because they
   share `pnames[]` with the positional ones. So `def m(x, k: 1)` had "2
   slots" and `m(3, 4)` passed the check.
2. It skipped any callee with `**kw`, so a surplus positional into `**kw` was
   never judged.
3. It treated a braceless keyword hash with no matching key as the positional
   options hash, even when the callee declares keywords. Ruby then treats it
   as keywords, so `g2(1, j: 2)` should raise "unknown keyword".

The instance-dispatch path (`emit_dispatch`) had its own copy of the count,
with the same slot error, and it skipped every call that had a keyword hash.
That is why `Kw.new.m(3, 4)` and the self-call inside `Kw#run` were wrong too.

## Fix

- The check is now one helper, `emit_call_arity_check`, used by both
  `emit_args_filled` and `emit_dispatch`. The dispatch's old copy is removed.
- It counts only positional parameters.
- It judges a `**kw` callee's positional count (too many or too few).
- For a callee that declares keywords, it takes a keyword hash as keywords.
  The new `callee_declares_kwargs` decides this, and
  `emit_unknown_kwarg_raise` uses it too; it now also returns early for a
  `**kw` callee.
- A missing required keyword now reports "missing keyword: :k" even with no
  keyword hash at the call.

The test is `test/surplus_arg_refusal.rb`. It holds the three reproducers,
plus variants: a direct and an instance call, a `**kw` shortfall, a missing
required keyword, valid keyword calls, and the options-hash idiom that must
keep working for a callee with no keywords. The CRuby messages match.

## Gate

Full gate, `make -k -j4 gate TEST_JOBS=-j4`:

```
Tests: 3996 pass, 2 fail, 0 error
FAIL: pkg.tmpdir.tmpdir_expand_usable      (known: root)
FAIL: socket_ipv6_and_class_methods        (known: no UDP)
Benchmarks: 62 pass, 0 fail, 0 error, 0 skip
Optcarrot: OK
infer-test: pass
spin-e2e: ALL GREEN
```

That full gate ran with an empty LANG, before the README asked for
`C.UTF-8`, so its rubyspec leg under-tested. I reran the rubyspec leg with
`LANG=C.UTF-8`:

```
exit=0, no extractor encoding errors
rubyspec-gate[language]: all 671 expected-PASS examples still pass
rubyspec-gate[core/array]: all 421 expected-PASS examples still pass
rubyspec-gate[core/string]: all 571 expected-PASS examples still pass
rubyspec-gate[core/hash]: all 192 expected-PASS examples still pass
rubyspec-gate[core/integer]: all 171 expected-PASS examples still pass
rubyspec-gate[core/range]: all 83 expected-PASS examples still pass
```

## Surprising / not fixed

- **The inlined yield path has no arity check at all.** This is a sibling
  site. `emit_inline_call_x` (`src/codegen_iter.c`) binds a yielding method's
  parameters with only the unknown-keyword check. So on master,
  `def y1(x) = yield(x); y1 { }` runs with `x` padded, and
  `def y(x, k: 1) = yield(x + k); y(1, 2) { }` drops the 2.

  I tried calling the same helper there (it fixes both). The full gate then
  failed `builtins_take_drop_while`, because of the next bug, so I left that
  change off this branch. Once the next bug is fixed, the change is small:
  call `emit_call_arity_check(c, m, argc, argv, 1)` (skipping the `fwd_encl`
  case) before `emit_unknown_kwarg_raise`.
- **A redefined free function resolves to its first def.** This is
  pre-existing on master: `comp_method_index_direct` returns the first
  top-level scope with the name. The program below prints `[:second]` in Ruby
  but raises "wrong number of arguments (given 1, expected 0)" on master and
  on this branch:

  ```ruby
  def tw(&b) = [:first]
  def tw(a)
    a.each { |x| yield x }
    [:second]
  end
  p tw([1]) { |x| x }
  ```

  `test/builtins_take_drop_while.rb` redefines `tw` the same way, and passes
  only because both bodies give `[1, 2]`. This probably deserves its own
  brief.
- **Commit author.** The commit is authored as `Claude <noreply@anthropic.com>`.
  It was pushed before the README added the `git config user.name/email` step.
  My attempt to amend the author and force-push was blocked by this session's
  permission policy. Re-author it on your side if needed, for example with
  `git commit --amend --reset-author` and a force-with-lease push. The
  trailer is the required one only.
