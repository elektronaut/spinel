A literal block passed to a method that forwards it with an anonymous `&` (`def install(&) = @keeper.install(&)`) to a method that stores it (`def install(&handler) = @handler = handler`) loses its captures of the caller's locals. If the block reads a captured local, Spinel refuses the program; if it writes a value-type local, the program compiles but the writes never reach the caller. Forwarding the same block with a named `&blk` works.

A block that sets a field on a captured local, forwarded through an anonymous `&`:

```ruby
class Keeper
  def install(&handler)
    @handler = handler
  end

  def fire(v) = @handler.call(v)
end

class Box
  attr_accessor :code
end

class Front
  def initialize
    @keeper = Keeper.new
  end

  def install(&) = @keeper.install(&)
  def fire(v) = @keeper.fire(v)
end

box = Box.new
front = Front.new
front.install { |value| box.code = value }
front.fire(7)
p box.code
```

CRuby prints `7`. Spinel refuses it: ``c.rb:24: unsupported proc referencing an uncaptured outer variable `box` (later slice): node 56 (BlockNode)``.

A block that adds to a captured integer compiles, but the additions are lost:

```ruby
class Keeper
  def install(&handler)
    @handler = handler
  end

  def fire(v) = @handler.call(v)
end

class Front
  def initialize
    @keeper = Keeper.new
  end

  def install(&) = @keeper.install(&)
  def fire(v) = @keeper.fire(v)
end

def run(front)
  total = 0
  front.install { |value| total += value }
  front.fire(3)
  front.fire(4)
  total
end

p run(Front.new)
```

CRuby prints `7`. Spinel prints `0`.

An anonymous `&` forwarder is always yield-inlined, so the literal block is spliced onto the forwarded call and becomes a proc there, but `mark_proc_captures` in `src/analyze.c` only recognizes an inlined forwarder whose block still becomes a proc when the forward goes to a poly receiver (`a_block_forwarded_into_poly`). The block's captured locals therefore get no cells.
