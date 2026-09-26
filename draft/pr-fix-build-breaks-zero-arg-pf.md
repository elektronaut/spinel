title: A proc form reached by a zero-argument poly call keeps its boxed parameters

Fixes #N.

A yielding method called through a poly receiver with a block gets a proc form, a clone that receives its arguments boxed from the dispatch arm. `make_yield_proc_forms` in `src/analyze.c` already sets an unknown parameter of that clone to `TY_POLY` (#4502). But the fixpoint's re-narrow reset (the "clears poly params" step) sets every `TY_POLY` parameter back to `TY_UNKNOWN` each round, sparing only block parameters and those marked `poly_dispatch_widened`, on the assumption that a call site will widen the rest again. No call site binds a clone's parameters, so a clone reached only by a zero-argument call (`o.w { ... }`, where `A#w` takes `x`) ended the fixpoint with its parameters unknown. `emit_proc_call_args` then read the boxed argument as `sp_int` (`sp_int _t1 = lv_x` from an `sp_RbVal`), and the C didn't compile.

In `make_yield_proc_forms`, a clone parameter that is made `TY_POLY` is now also marked `poly_dispatch_widened`, so the reset spares it. That field's own comment describes this case: the value arrives boxed from the dispatch and must survive the reset. Parameters that already have a type are untouched.

The `ArgumentError` for a class whose method needs arguments comes from #5024, already on master.

Tests: `test/poly_zero_arg_yield_pf.rb` covers the issue's reproducer; optional and rest parameters on yielding methods (`def v(x, y = 1)`, `def v(x, *r)`), checking that the message words the count as CRuby does (`expected 1..2`, `expected 1+`); and a zero-argument poly call without a block to a method that takes one argument. It fails on master and matches CRuby 4.0 with this change. `make gate` is clean apart from the two known sandbox failures, `pkg.tmpdir.tmpdir_expand_usable` and `socket_ipv6_and_class_methods`.
