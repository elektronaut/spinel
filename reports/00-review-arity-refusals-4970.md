# review-arity-refusals-4970: report

**Status:** done
**PR:** matz/spinel#4970
**Branch:** `fix-surplus-arg-refusal` (fetched at `70c116ec`, the amended tip; new commit on top, fast-forward push, no force)
**Commit:** `6b542986` — "A keyword key binds only a keyword parameter, never a positional one of the same name"
**Pushed:** 10:38 Oslo, before the 11:20 deadline, after the full gate finished.

## Findings

### comment 4102284163 (src/codegen_fold.c:6819): fixed in `6b542986`

Verified before fixing. On the branch tip, `def f(x, k: 1)` called as `f(x: 2)` printed `[{x: 2}, 1]`, `f(1, x: 2)` printed `[1, 1]`, and `def req_kw(x, k:)` called as `req_kw(k: 2)` raised `missing keyword: :x`. CRuby raises `wrong number of arguments (given 0, expected 1)`, `unknown keyword: :x`, and `wrong number of arguments (given 0, expected 1; required keyword: k)`.

Reply:

> Fixed in 6b542986. `emit_call_arity_check` and `emit_unknown_kwarg_raise` now match a key only against keyword parameters, so `f(x: 2)` against `def f(x, k: 1)` raises the positional arity error and `f(1, x: 2)` raises `unknown keyword: :x`. The arity error is checked before any keyword error, and it now includes CRuby's `; required keyword: k` suffix (so `req_kw(k: 2)` gives CRuby's message). `test/kw_key_names_positional.rb` covers the direct and instance-dispatch paths.

## Root cause

When the callee declared keywords, the missing-argument loop in `emit_call_arity_check` counted a positional parameter as supplied if the keyword hash had a key with the same name. `emit_unknown_kwarg_raise` also accepted any parameter name as a known key. As a result, a key with a positional parameter's name was accepted, and neither the arity error nor the unknown-keyword error was raised. The loop also said "missing keyword" for a positional parameter whenever a keyword hash was present.

## Fix

Only keyword parameters (`callee_param_is_declared_kwarg`, plus `callee_has_kwarg` for keys) claim a key. The checks now run in CRuby's order: first surplus positionals, then too few positionals, then missing keywords, then unknown keywords. A new helper, `arity_required_kw_suffix`, adds the required-keyword suffix to the arity message in both the keyword branch and the `**kw` branch. It follows the rule already used in `codegen_call.c` around line 15332. Callees without declared keywords are unchanged, so the options-hash idiom (`def opts(x, o = {})`) still binds positionally.

## Diff stat

```
 src/codegen_fold.c                       | 54 +++++++++++++++++++++++++-------
 test/kw_key_names_positional.rb          | 42 +++++++++++++++++++++++++
 test/kw_key_names_positional.rb.expected | 18 +++++++++++
 3 files changed, 102 insertions(+), 12 deletions(-)
```

`test/kw_key_names_positional.rb` contains the finding's three shapes, the same calls through instance dispatch, an optional positional with a same-named key, surplus with a required keyword, a `**kw` callee, and missing versus unknown keyword ordering. The existing `test/surplus_arg_refusal.rb` still passes. The `.expected` file was produced with the container's Ruby 3.3.6 rather than CRuby 4.0, because no CRuby 4.0 output was available. The output is only error messages and small arrays, whose format is the same in both versions.

## Gate summary

```
Tests: 3997 pass, 2 fail, 0 error
FAIL: pkg.tmpdir.tmpdir_expand_usable        (known: root)
FAIL: socket_ipv6_and_class_methods          (known: no UDP)
Benchmarks: 62 pass, 0 fail, 0 error, 0 skip
spin-e2e: ALL GREEN
rubyspec-gate[language]: all 671 expected-PASS examples still pass
rubyspec-gate[core/array]: all 421 expected-PASS examples still pass
rubyspec-gate[core/string]: all 571 expected-PASS examples still pass
rubyspec-gate[core/hash]: all 192 expected-PASS examples still pass
rubyspec-gate[core/integer]: all 171 expected-PASS examples still pass
rubyspec-gate[core/range]: all 83 expected-PASS examples still pass
```

## Surprising

- The brief's copy of the comment ends at "Apply the predicate in both checks:" and the suggested diff is missing, so the fix was written from the finding's text.
- CRuby adds `; required keyword: k` to the arity message even when the call passes `k`. `req_kw(k: 2)` therefore reports `given 0, expected 1; required keyword: k`, and not the plain positional error the finding describes.
- This session originally claimed `00-review-redefined-def-4972` too, then set it back to `open` for another worker at the user's request.
