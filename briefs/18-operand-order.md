status: open
branch: fix-poly-array-op-assign

# operand-order

Two codegen bugs around array operators. Probably separate root causes; one branch each.

## jade-stoat

poly Array op-assign with a different-kind rhs (`m = [1, "x"]; m -= ["x"]`) doesn't compile

- `18-operand-order/y_poly_mixed_stmt.rb` (CRuby 4.0 output in `y_poly_mixed_stmt.rb.expected`)

## birch-raven

plain binary `$a + [f]` / `$a.union([f])` reads the receiver after the argument's prelude

- `18-operand-order/plain_binary_general.rb` (CRuby 4.0 output in `plain_binary_general.rb.expected`)

