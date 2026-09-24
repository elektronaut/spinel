status: claimed
branch: fix-block-forward-errors

# block-forward-errors (handles: dun-grebe, pearl-avocet)

Two separate root causes; one branch each.

## dun-grebe: a poly receiver's `#pf` arm has no `super`

When the called method forwards its block to `super` (`def on(&) = super(&)`)
and the receiver is polymorphic, the program raises
`super: no superclass method 'on#pf'` (NoMethodError).

- `24-block-forward-errors/poly_pf_super.rb`

## pearl-avocet: a literal block reading the outer block param, passed to a method on an ivar receiver

`@reg.set { |v| handler.call(v) }` inside `def install(&handler)` fails the C
build with `'_cell_handler' undeclared`. It's the ivar-receiver sibling of
pewter-crake's r16 (brief 03). `a_block_is_lifted` resolves the target via
`infer_type(recv)`, which doesn't see the ivar's type at that point.

- `24-block-forward-errors/ivar_recv_cell.rb`
