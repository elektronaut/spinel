status: done
branch: fix-rest-default-binding

# rest-default-binding

Argument binding with optional params, *rest, splats and defaults reading earlier params. Several are silent wrong values. Probably 2-3 root causes; one branch per root cause.

## quartz-wren

`def r(a = {}, *rest, c); r(5)` -> [5, [], 5]: arg_slot_for_param ignores a leading optional with *rest/**kw

- `07-rest-default-binding/x_rest_plain.rb` (CRuby 4.0 output in `x_rest_plain.rb.expected`)

## ochre-vole

default reading an earlier param together with `**kw` doesn't compile ("undeclared lv_x")

- `07-rest-default-binding/kwrest_pd.rb` (CRuby 4.0 output in `kwrest_pd.rb.expected`)

## pale-scoter

`def m(n, *r, k: n + r.size) = k; m(3, 1, 2)`: a keyword default reading an earlier param in a method with *rest fails C compile (undeclared lv_n); the default-reads-earlier-param path in emit_args_filled is off for *rest methods

- `07-rest-default-binding/adj_rest_kw_default.rb` (CRuby 4.0 output in `adj_rest_kw_default.rb.expected`)

## sable-ruff

`*nil` into a rest param (`def r(*xs); r(*nil)`) gives `[nil]` where CRuby gives `[]`; and an instance-method call `O.new.m(*7)` gives `m([7],0)`: the dispatch-path splat layout (`splat_at_d` in codegen_fold.c) only lowers poly/unknown operands, same one-line gap #4898 fixed in emit_args_filled

- `07-rest-default-binding/h_adv.rb` (CRuby 4.0 output in `h_adv.rb.expected`)

## mossy-godwit

splat + trailing positional + keywords into an optional: `kw(*[1], 2, k: 3)` into `def kw(a, b = 0, k: 1)` gives kw(1,0,3) (CRuby kw(1,2,3)); `kw(*[], 2, k: 3)` gives kw(nil,0,3). Missed by matz's f09820a5. Instance-method dispatch too: `O.new.m(*[1, 2], 3)` gives m(1,2) (CRuby ArgumentError), `O.new.o(*[1], 3)` gives o(1,0,0) (CRuby o(1,3,0)).

- `07-rest-default-binding/i3_adv.rb` (CRuby 4.0 output in `i3_adv.rb.expected`)

