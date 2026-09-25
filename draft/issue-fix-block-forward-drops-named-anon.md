title: A named `&blk` passed through an anonymous `&` forwarder never reaches the method that stores it

A block handed through two forwarding methods, first a named `&blk` (`def install(&blk) = @f.install(&blk)`) and then an anonymous `&` (`def install(&) = @k.install(&)`), to a method that stores it arrives as nil, so a later `@h.call` raises NoMethodError. Named into named and anonymous into anonymous both work; only this mixed shape loses the block.

```ruby
class Keeper
  def install(&h) = @h = h
  def fire(v) = @h.call(v)
end
class Front
  def initialize = @k = Keeper.new
  def install(&) = @k.install(&)
  def fire(v) = @k.fire(v)
end
class Outer
  def initialize = @f = Front.new
  def install(&blk) = @f.install(&blk)
  def fire(v) = @f.fire(v)
end
o = Outer.new
o.install { |v| p v * 2 }
o.fire(5)
```

CRuby prints `10`. Spinel raises `undefined method 'call' for nil (NoMethodError)`.

`Outer#install` is a real function, and it inlines `Front#install` with `blk` as a proc: the splice has no literal block (`g_block_id` is -1) and records the proc in `g_yield_proc_ref`, which only `yield` reads. The anonymous `&` forward inside goes through `resolve_forwarded_block` in `src/codegen_fold.c`, which only answers a literal block, finds none, and `Keeper#install` gets `NULL`.
