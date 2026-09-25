A block passed to a method that forwards it with anonymous `&` (`def install(&) = @register.handle(&)`) to another method that stores it (`def handle(&handler) = @handler = handler`) loses its ivar writes. When the stored block is called later, `@code = value` inside the block does not update the object that wrote the block, so that object keeps its old value. This happens when the forwarding method is inlined into the caller. The same goes for a named `&blk`, `Proc.new(&blk)`, and forwarding through two methods. With more ivars or more calls the program can segfault instead.

```ruby
class Register
  def initialize
    @handler = nil
  end

  def handle(&handler)
    @handler = handler
  end

  def poke(value) = @handler.call(value)
end

class Bus
  attr_reader :register

  def initialize
    @register = Register.new
  end

  def install(&) = @register.handle(&)
end

class Recorder
  attr_reader :code

  def initialize(bus)
    @code = 0
    bus.install { |value| @code = value }
  end
end

bus = Bus.new
recorder = Recorder.new(bus)
bus.register.poke(7)
puts recorder.code
```

CRuby prints `7`. Spinel prints `0`.

When `Bus#install` is inlined into `Recorder#initialize`, the forwarded `&` turns the caller's spliced block into a proc in `emit_proc_literal` (`src/codegen.c`). That proc captures the current `g_self`, which inside the splice is the inlined callee's receiver (the `Bus`), not the `Recorder`. The block body treats that self as a `Recorder`, so `@code = value` writes into the `Bus` at the `Recorder`'s field offset.
