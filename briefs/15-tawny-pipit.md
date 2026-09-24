status: done
branch: fix-poly-zero-arg-arity

# tawny-pipit

Same shortfall PR #4958 fixed in the argument form of emit_poly_method_dispatch, but in the zero-argument dispatch path (codegen_call.c, the nrequired == 0 filters near the attr-reader arms). Check PR #4958 (poly_arm_count) and reuse it if it has merged.

## tawny-pipit

- **tawny-pipit**: zero-argument poly dispatch path has the same nrequired-as-count shortfall: `o.h` on `def h(a = {}, c)` raises NoMethodError, CRuby ArgumentError (codegen_call.c ~6512/6572). Found by the brief-08 cloud session.

- `15-tawny-pipit/tawny.rb` (CRuby 4.0 output in `tawny.rb.expected`)

