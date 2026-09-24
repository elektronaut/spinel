# amber-shrike: report

**Status:** done
**Branch:** `fix-kwdefault-poly-ivar-narrowing` (on origin, based on upstream/master `032c037a`)
**Commit:** `91a65612a50198787e6d764dc653139ff5e53476`: "A default reading a poly ivar widens its parameter in the re-narrowing loop"

## Root cause

After the main fixpoint, a re-narrowing loop in `src/analyze.c` resets poly ivars
and poly parameters to UNKNOWN and iterates. In each iteration it binds parameters
from the previous iteration's settled state and only then re-clears the reset
ivars (the #4437 ordering). `infer_default_param_types` ran *after* the re-clear,
so a default reading a reset ivar (`def select(romh: @rom)`, where `@rom` is poly)
saw UNKNOWN in every iteration and was skipped. The parameter kept the only
explicit call site's class (`select(romh: @ram)`, a `RAMBank`), and passing the
default `Bank` raised `wrong argument type Bank (expected RAMBank) (TypeError)`.

## Fix

The loop now also runs `infer_default_param_types` right after `infer_param_types`,
before the re-clear, and counts its change like the other passes. The existing
call after the re-clear stays for defaults over state that iteration derives.
Types only widen, so an UNKNOWN read there is harmless. The fix covers positional
and keyword defaults alike, since both go through the same pass.

## Diff stat

```
 src/analyze.c                                      |  9 +++-
 test/default_poly_ivar_not_narrowed_variants.rb    | 55 ++++++++++++++++++++++
 ...ult_poly_ivar_not_narrowed_variants.rb.expected |  8 ++++
 test/kwdefault_poly_ivar_not_narrowed.rb           | 42 +++++++++++++++++
 test/kwdefault_poly_ivar_not_narrowed.rb.expected  |  4 ++
 5 files changed, 117 insertions(+), 1 deletion(-)
```

Tests:
- `kwdefault_poly_ivar_not_narrowed.rb` is `r30.rb`, with the brief's CRuby 4.0
  `.expected`.
- `default_poly_ivar_not_narrowed_variants.rb` has two variants:
  - a positional default (`def aim(t = @target)`)
  - a keyword default next to another keyword (`pour(into: @src, n: 1)`)

Both tests fail on unpatched master with the brief's TypeError. The variants'
`.expected` came from the container's older Ruby. The output is plain strings
from `puts`, so it doesn't depend on the Ruby version.

## Gate (`LANG=C.UTF-8 make -k -j4 gate TEST_JOBS=-j4`)

```
Tests: 3997 pass, 2 fail, 0 error
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

The two failures are the known sandbox ones in the README:
`pkg.tmpdir.tmpdir_expand_usable` and `socket_ipv6_and_class_methods`. There were
no rubyspec extraction errors. I committed only after the whole gate had finished.

## Surprising / follow-ups

- **Possible sibling sites (not verified, not changed).** In the same loop, four
  more passes run after the ivar re-clear and could read a reset ivar the same way:
  `bind_coerce_operator_params`, `infer_param_hash_value`, `propagate_prep_params`
  and `infer_string_params`. I found no reproducer for any of them, so I left
  them alone.
- The brief says the badline workaround is an untyped RBS seed. With this fix,
  that seed should no longer be needed.
- This worktree is at `../work2`, because `../work` still holds the zinc-shrew
  worktree.
