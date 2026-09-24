status: claimed
branch: fix-poly-arm-arity

# poly-arm-arity

Poly-receiver dispatch arms and arity.

## dusky-newt

poly receiver (element of [A.new, B.new]) dispatch ignores arm arity: extra args silently dropped; `**kw` arm gets NULL and segfaults

- `08-poly-arm-arity/poly_extra_args.rb` (CRuby 4.0 output in `poly_extra_args.rb.expected`)
- `08-poly-arm-arity/poly_kwrest_null.rb` (CRuby 4.0 output in `poly_kwrest_null.rb.expected`)

## xenon-finch

poly dispatch arm with a leading optional is dropped (NoMethodError), even `o.h(5)`

- `08-poly-arm-arity/x_dispatch_plain.rb` (CRuby 4.0 output in `x_dispatch_plain.rb.expected`)

