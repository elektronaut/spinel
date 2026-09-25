title: `new` on a Class value raises NoMethodError for a Struct with its own initialize, and for any Struct read from a container

When a method returns a Struct class and the program calls `k.new(v)` on the result with positional arguments, Spinel raises NoMethodError if that Struct defines its own `initialize`. The splat form `k.new(*args)` builds it fine.

```ruby
class A
  def initialize(x) = @x = x
  def to_s = "A(#{@x})"
end
S = Struct.new(:x, :y) do
  def initialize(a) = super(a, a * 2)
end
def pick(i) = i == 0 ? A : S
def build(i, *args) = pick(i).new(*args)
def one(i, v) = pick(i).new(v)
puts build(0, 5)
v = build(1, 5)
p v
w = one(1, 6)
p w
```

CRuby prints `A(5)`, `#<struct S x=5, y=10>`, `#<struct S x=6, y=12>`. Spinel prints the first two lines, then raises `undefined method 'new' for an instance of Class (NoMethodError)` at `one(1, 6)`.

A Struct class read out of a container fails the same way, even a plain one with no `initialize` of its own.

```ruby
S = Struct.new(:x, :y)
REG = {0 => S}
p REG.fetch(0).new(5, 6)
```

CRuby prints `#<struct S x=5, y=6>`. Spinel raises `undefined method 'new' for an instance of Class (NoMethodError)`.

Both dispatches that build a Class value's `new` in `codegen_call.c` leave the Struct out: the positional one skips a Struct that has its own `initialize` (`if (initm >= 0) continue;`), and the boxed-receiver one skips every `is_struct` class, so the switch falls through to its NoMethodError default.
