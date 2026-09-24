# tawny-pipit: report

**Status:** done
**Branch:** `fix-poly-zero-arg-arity` (based on upstream/master `7b0a60d3`, which includes #4958)
**Commit:** `409ccf3f` "A poly receiver's zero-argument arm raises when its method needs arguments"

## Root cause

The zero-argument path of `emit_poly_method_dispatch` kept a class's arm
only when `nrequired == 0`. That test did two wrong things.

- `nrequired` is an index, not a count. A leading optional
  (`def h(a = {}, c)`) has `nrequired == 2`, so the arm was dropped.
- Any method that needs arguments was dropped too, instead of raising.

Either way `o.h` fell through to the switch's default and answered
NoMethodError, where CRuby raises ArgumentError. It's the same shortfall #4958
fixed in the argument form. The same `nrequired == 0` gate also guarded the
Object-reopen default arm (`class Object; def zz(x)`), so `5.zz` through a
poly slot answered NoMethodError as well.

## Fix

The fix reuses #4958's `poly_arm_count`, through a small wrapper
`poly_arm_refuses_none(c, mi, exp, n)` that asks for a zero-argument call.
When a method refuses zero arguments:

- its class arm is `case k: sp_raise_cls("ArgumentError", "wrong number of
  arguments (given 0, expected …)")`. That's skipped when the class also has a
  reader of that name, which keeps the old reader arm;
- the class-0 and primitive-reopen dispatch keys count it as a candidate, as
  #4958 did for `cls0_cand2`/`prim_cand2`;
- a refusing method reopened on Object becomes the switch's `default:`
  ArgumentError.

Arms that bind are unchanged: they still require `nrequired == 0`. I only
added the refusing case, which keeps the change conservative.

Note: after #4958 merged, `poly_arm_count`'s `exp` changed to include the
"given N, " prefix (commit `00bac566`). The new arms print `(%s)`.

## Diff stat

```
 src/codegen_call.c                            | 28 +++++++++++++-
 test/poly_zero_arg_arity.rb                   | 21 +++++++++++
 test/poly_zero_arg_arity.rb.expected          |  2 +
 test/poly_zero_arg_arity_variants.rb          | 54 +++++++++++++++++++++++++++
 test/poly_zero_arg_arity_variants.rb.expected | 13 +++++++
 5 files changed, 117 insertions(+), 1 deletion(-)
```

Tests: `test/poly_zero_arg_arity.rb` is the brief's reproducer. The variants
file `test/poly_zero_arg_arity_variants.rb` covers:

- a plain required param (`expected 1`);
- a post-rest required param `def t(*r, x)` (`expected 1+`);
- an optional-then-required param `def g(a, b = 2)` (`expected 1..2`);
- arms that bind beside arms that refuse, in one dispatch;
- a class whose `h` is an `attr_reader`;
- the Object-reopen default arm, with Integer and String receivers.

Both files match CRuby. On master, the variants stop at the first call with
`undefined method 'h' for an instance of A (NoMethodError)`.

## Gate (`make -k -j4 gate TEST_JOBS=-j4`, `LANG=C.UTF-8`)

```
Tests: 4007 pass, 2 fail, 0 error
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

The two test failures are the known environment ones
(`pkg.tmpdir.tmpdir_expand_usable`, `socket_ipv6_and_class_methods`).

## Found, not fixed (pre-existing on master, separate root cause)

A **yielding** method with parameters, reached only through a zero-argument
poly call, gets an untyped proc form. The C doesn't compile, with or without
this fix (3 identical errors on master):

```ruby
class A; def w(x) = yield(x); end
class B; def w = yield(:b); end
class C; def w(x, y) = yield(x, y); end
[A.new, B.new, C.new].each do |o|
  p o.w { |v| [:blk, v] }
rescue ArgumentError => e
  p e.message
end
# CRuby: "wrong number of arguments (given 0, expected 1)", [:blk, :b], "...expected 2)"
# Spinel: error: incompatible types when initializing type 'sp_int' using type 'sp_RbVal'
#         (in sp_A_w_pf / sp_C_w_pf)
```

`w`'s params are never typed because no call site passes arguments, and
`sp_A_w_pf` still reads them from the boxed argument slots as `sp_int`. The
fix probably belongs in the proc-form emitter (an untyped param should default
to poly), not in dispatch.
