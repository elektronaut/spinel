# 08-poly-arm-arity — report

**Fix branch:** `fix-poly-arm-arity` (on origin), commit `598f9f4e`
"A poly receiver's dispatch arm judges the call's count as its method does"

## Root cause

`emit_poly_method_dispatch` (src/codegen_call.c), argument form, decided each
class's arm with `pos_argc + fills >= scope.nrequired`. `nrequired` is the index
past the last required parameter, not a count, and there was no upper-bound check:

- **dusky-newt, extra args:** `B#m(x)` passed the lower-bound check for `o.m(3, 4)`,
  and the arm cut the arguments off at the arm's `nparams`.
- **dusky-newt, `**kw` NULL:** the kwrest-building branch only ran when the call had a
  keyword hash (`kwh >= 0`). With no keywords the parameter got
  `emit_arg_or_default`, which is `NULL`, and `kw.size` crashed.
- **xenon-finch:** for `def h(a = {}, c)`, `nrequired` is 2, so `o.h(5)` dropped every
  arm and the call hit the NoMethodError default. The arguments were also bound by
  position, not required-first as `arg_slot_for_param` does, and so was the
  argument-vs-parameter type check (`arm_key_incompat`).

## Fix

New `poly_arm_count()` returns bind (1), refuse (-1) or drop (0). It counts
positional parameters as CRuby does and reports the CRuby range text (`1`,
`1..2`, `1+`). The candidate count, the `case 0` guard, the prim-reopen key and
the arm loop all use it now. A refusing arm becomes
`case k: sp_raise_cls("ArgumentError", "wrong number of arguments (given N, expected R)")`.
The old drop rule stays for a missing required keyword, a keyword hash no parameter
takes, and synthesized (`__`) or `cs_synth` scopes. Arm arguments and the arm type
check go through `arg_slot_for_param` when `opt_before_required`. `**kw` always gets a
`SymPolyHash`, empty when the call passes no keywords.

## Diff stat

```
 src/codegen_call.c                         | 81 ++++++++++++++++++++++++------
 test/poly_arm_arity_count.rb               | 31 ++++++++++++
 test/poly_arm_arity_count.rb.expected      |  6 +++
 test/poly_arm_kwrest_empty.rb              | 14 ++++++
 test/poly_arm_kwrest_empty.rb.expected     |  6 +++
 test/poly_arm_leading_optional.rb          | 16 ++++++
 test/poly_arm_leading_optional.rb.expected |  8 +++
 7 files changed, 147 insertions(+), 15 deletions(-)
```

All three brief reproducers match the CRuby 4.0 expected output.

## Gate

```
Tests: 3998 pass, 2 fail, 0 error
infer-test: pass
Benchmarks: 62 pass, 0 fail, 0 error, 0 skip
rubyspec-gate[language]: all 671 expected-PASS examples still pass
rubyspec-gate[core/array]: all 421 expected-PASS examples still pass
rubyspec-gate[core/string]: all 571 expected-PASS examples still pass
rubyspec-gate[core/hash]: all 192 expected-PASS examples still pass
rubyspec-gate[core/integer]: all 171 expected-PASS examples still pass
rubyspec-gate[core/range]: all 83 expected-PASS examples still pass
```

The two failures are caused by the cloud sandbox, not this change:
- `socket_ipv6_and_class_methods`: "cannot create UDP socket" (no UDP in the
  container). The generated C is byte-identical to master's.
- `pkg.tmpdir.tmpdir_expand_usable`: master's compiler gives the same wrong output
  (`false true false`) here, because the container runs as root. Apart from
  `#line` directives, the generated C matches master's.

The #4847 infer-test rows passed this time. `tools/rubyspec/extract.rb:66`
raised `invalid byte sequence in US-ASCII` on a few spec files because the
container's locale is not UTF-8. That is a gate-environment issue, and the
rubyspec gates still report all expected-PASS examples passing.

## Surprises / follow-ups

- **Zero-argument dispatch not fixed:** it is a separate path (`nrequired == 0`
  filters around the attr-reader arms, near codegen_call.c:6512/6572). There,
  `o.h` on `def h(a = {}, c)` still raises NoMethodError, where CRuby raises
  ArgumentError. It's the same shortfall in the other emitter, and I left it out
  of scope.
- **Expected files made with Ruby 3.3:** the container only has Ruby 3.3, so I
  generated the new tests' `.expected` files with it. The `{a: 2}` hash-inspect
  line in `poly_arm_kwrest_empty.rb.expected` was edited by hand to 4.0's format.
  Worth re-checking against CRuby 4.0.
