status: open
branch: fix-dispatch-arm-gaps

# dispatch-arms-a

Dispatch arms skipped or taking the wrong constructor path. Check doc/internals.md for a 'known dispatch gap' note first.

## yarrow-hare

inline-only override (`&blk` only .call/.nil?) arm skipped in dispatch; base runs instead

- `10-dispatch-arms-a/inline_arm_skipped.rb` (CRuby 4.0 output in `inline_arm_skipped.rb.expected`)

## auburn-gannet

Class-value new arm for a class whose initialize yields or forwards anonymous `&` goes through allocation-only sp_B_new, ivars never set: `B(,)` vs `B(1,none)`, silently

- `10-dispatch-arms-a/adj_yield_arm.rb` (CRuby 4.0 output in `adj_yield_arm.rb.expected`)

