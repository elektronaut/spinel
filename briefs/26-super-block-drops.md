status: done
branch: fix-super-anon-block

# super-block-drops (handles: misty-heron, coral-bunting)

Found by the brief-24 session. Both reproduce on master. Probably separate
root causes; one branch each.

## misty-heron: poly dispatch drops the block for `super(&)` into a yielding ancestor (silent)

The dispatch arm for PfA inlines `super(&)` with the yields as `(void)(1LL)`, so
the anonymous `&` never reaches the spliced block; only PfB's pair prints.
Calling `k.new.each_twice { }` directly takes the `#pf` clone and works.

- `26-super-block-drops/poly_super_yield.rb`

## coral-bunting: bare `super` from `def on(tag, &)` doesn't forward the block

A bare `super` doesn't pass an anonymous `&` block on to a parent that keeps it
as `&handler`: "undefined method 'call' for nil".

- `26-super-block-drops/bare_super_anon.rb`
