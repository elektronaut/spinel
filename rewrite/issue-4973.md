When a method forwards its block into a constructor whose `initialize` stores it (`def initialize(&handler) = @handler = handler`), the block never arrives. An anonymous forward, `def install(&) = Reg.new(&)`, passes `nil`, so the first call to the stored handler raises. A named forward, `Reg.new(1, &blk)`, fails to compile. A literal block to `new` that reads the outer method's block param, `Register.new(1) { |v| handler.call(v) }`, is refused. The same happens at top level and in instance methods.

An anonymous `&` forwarded into `new`:

```ruby
class Reg
  def initialize(&handler)
    @handler = handler
  end

  def poke(v) = @handler.call(v)
end

def install(&) = Reg.new(&)

install { |v| puts v }.poke(7)
```

CRuby prints `7`. Spinel raises `undefined method 'call' for nil (NoMethodError)`.

A named `&blk` forwarded into `new`, from an instance method, with a block that captures a caller local:

```ruby
class Reg
  def initialize(x, &handler)
    @x = x
    @handler = handler
  end

  def poke(v) = @handler.call(v)
end

class Bus
  def install(&blk)
    @reg = Reg.new(1, &blk)
  end

  def poke(v) = @reg.poke(v)
end

class Box
  attr_accessor :code
end

bus = Bus.new
box = Box.new
bus.install { |value| box.code = value }
bus.poke(7)
p box.code
```

CRuby prints `7`. Spinel's C build fails with `b.rb:12: error: ‘lv_blk’ undeclared (first use in this function)`.

A literal block to `new` that reads the outer block param:

```ruby
class Register
  def initialize(base, &handler)
    @base = base
    @handler = handler
  end

  def poke(value) = @handler.call(value)
end

class Bus
  def install(&handler)
    @register = Register.new(1) { |value| handler.call(value) }
  end

  def poke(value) = @register.poke(value)
end

bus = Bus.new
bus.install { |value| puts value }
bus.poke(7)
```

CRuby prints `7`. Spinel refuses it with `` r16.rb:12: unsupported proc referencing an uncaptured outer variable `handler` (later slice) ``.

The forwarding method is yield-inlined into its caller, and the stored-block `initialize` arm of `emit_class_new_call` in `src/codegen_call.c` emits the call's block argument as written, so `&blk` names a local no inline site declares and `&` becomes `NULL`. Separately, `src/analyze.c` looks `Klass.new` up as a class method `new`, which doesn't exist without a `def self.new`, so neither the forward nor the literal block counts as escaping into a stored `&handler`, and the block's captures get no cells.
