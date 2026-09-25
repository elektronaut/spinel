title: `puts obj` and `"#{obj}"` ignore the class's own `to_s` when the object's class is picked at run time

When a program builds objects whose class is chosen at run time (`pick(i).new(5)` where `pick` returns `A` or `B`), and those classes are small immutable ones (only Integer, Float, true/false or String ivars, set in `initialize`) that Spinel stores by value, `puts obj` and `"#{obj}"` print the default `#<A:0x...>` instead of calling the class's own `to_s`. Calling `obj.to_s` directly works.

```ruby
class A
  def initialize(x) = @x = x
  def to_s = "A(#{@x})"
end
class B
  def initialize(x) = @x = x
  def to_s = "B(#{@x})"
end
A.new(1)
B.new(2)
def pick(i) = i == 0 ? A : B
def build(i) = pick(i).new(5)
puts build(0)
puts build(1)
v = build(0)
puts "#{v}"
puts v.to_s
```

CRuby prints `A(5)`, `B(5)`, `A(5)`, `A(5)`. Spinel prints `#<A:0x00007f08b8820030>`, `#<B:0x00007f08b88200b0>`, `#<A:0x00007f08b8820130>`, `A(5)`.

`p obj` ignores the class's own `inspect` in the same situation:

```ruby
class A
  def initialize(x) = @x = x
  def inspect = "#<A #{@x}>"
end
class B
  def initialize(x) = @x = x
  def inspect = "#<B #{@x}>"
end
A.new(1)
B.new(2)
def pick(i) = i == 0 ? A : B
def build(i) = pick(i).new(5)
p build(1)
puts build(1).inspect
```

CRuby prints `#<B 5>`, `#<B 5>`. Spinel prints `#<Object>`, `#<B 5>`.

The runtime renders a boxed object through the generated `sp_obj_to_s_sw` and `sp_obj_inspect_sw` dispatchers, emitted by `emit_obj_inspect_dispatch` in `src/codegen.c`. Both skip value-type classes (`comp_ty_value_obj`), so a boxed value-type object falls to the default rendering past the user's `to_s` or `inspect`. The inline dispatch that `obj.to_s` compiles to already handles value types, which is why the last line is right.
