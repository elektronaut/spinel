title: `new` on a Class value builds an object with no ivars set when its initialize yields

When a class's `initialize` yields (or forwards an anonymous `&` block) and the class is constructed through a Class value, for example one read out of a Hash or returned by a method, Spinel returns an object whose `initialize` never ran: every instance variable is unset. There is no error.

```ruby
class A
  def initialize(x) = @x = x
  def to_s = "A(#{@x})"
end

class B
  def initialize(x)
    @x = x
    @y = block_given? ? yield(x) : "none"
  end

  def to_s = "B(#{@x},#{@y})"
end

B.new(9) { |v| v }
[A, B].each { |k| puts({ 0 => k }.fetch(0).new(1)) }
```

CRuby prints `A(1)`, `B(1,none)`. Spinel prints `A(1)`, `B(,)`.

A yielding `initialize` has no C function of its own: a constant `B.new` site splices its body (`emit_ctor_yield_inline` in `codegen_call.c`), and the generated `sp_B_new` only allocates. The switch arms of a `new` whose class is known only at run time call `sp_B_new`, so the body never runs.
