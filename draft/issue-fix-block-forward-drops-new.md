title: A class method's `new(&h)` or `self.new(&h)` doesn't hand its block to an `initialize(&h)` that stores it

A class method that forwards its block to the constructor (`def self.make(&h) = new(&h)`), where `initialize(&h)` stores the block, loses the block or doesn't compile, depending on how `new` is spelled. Bare `new(&h)` produces C that doesn't compile, and `self.new(&h)` builds the object with no block, so a later `@h.call` raises NoMethodError. The same happens when the receiver is any Class value, such as a method's return value: without arguments the block is dropped, and with arguments the call is refused. This happens without any inlining; the forward from an inlined method into a static `Klass.new(&)` is #4973.

Bare `new(&h)` in a class method:

```ruby
class Reg
  def initialize(&h) = @h = h
  def self.make(&h) = new(&h)
  def poke(v) = @h.call(v)
end
p Reg.make { |v| v * 2 }.poke(21)
```

CRuby prints `42`. Spinel fails to build the C: `class_new_bare.rb:3: error: too few arguments to function ‘sp_Reg_new’`.

`self.new(&h)` in a class method:

```ruby
class Reg
  def initialize(&h) = @h = h
  def self.make(&h) = self.new(&h)
  def poke(v) = @h.call(v)
end
p Reg.make { |v| v * 2 }.poke(21)
```

CRuby prints `42`. Spinel raises `undefined method 'call' for nil (NoMethodError)`.

A Class value chosen at runtime, with an argument and a block:

```ruby
class Reg
  def initialize(n = 0, &h) = (@n = n; @h = h)
  def poke(v) = @h.call(v + @n)
end
class Other
  def initialize(n = 0, &h) = (@n = n; @h = h)
  def poke(v) = @h.call(v - @n)
end
def pick(i) = i == 0 ? Reg : Other
def mk1(i, &h) = pick(i).new(10, &h)
p mk1(0) { |v| v * 2 }.poke(1)
p mk1(1) { |v| v * 2 }.poke(20)
```

CRuby prints `22` and `20`. Spinel refuses it: ``classval.rb:10: unsupported call: node 73 (CallNode `new`) recv=CallNode/ty49 argc=1 arg0ty3``. With `pick(i).new(&h)` instead (no argument), CRuby prints `2` and `40`, and Spinel raises `undefined method 'call' for nil (NoMethodError)`.

In `src/codegen_call.c`, each spelling of `new` fills the constructor's `&blk` slot on its own. The bare `new(...)` path in a class method leaves the slot out of the `sp_Reg_new` call, the Class-value dispatches (`self.new`, `pick(i).new`) write `NULL` through `emit_ctor_block_slot` whatever block the call carries, and the positional and boxed-receiver dispatches only accept a call with no block.
