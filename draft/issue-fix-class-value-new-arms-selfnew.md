title: `new` on a Class value never calls a class's own `self.new`, and fails to compile when one returns a non-instance

When a method returns a class and the program calls `k.new(...)` on the result, a class that defines its own `def self.new` should be built by that method, whatever it returns. On Spinel, once any class in the program defines `self.new`, such a call stops compiling if that method returns something other than an instance.

```ruby
class A
  def initialize(x) = @x = x
  def to_s = "A(#{@x})"
end
class C
  def self.new(x) = "C.new(#{x})"
end
def pick(i) = i == 0 ? A : C
def build(i, *args) = pick(i).new(*args)
def one(i, v) = pick(i).new(v)
puts build(0, 5)
puts one(1, 6)
puts build(1, 7)
```

CRuby prints `A(5)`, `C.new(6)`, `C.new(7)`. Spinel fails in the C compiler: `error: incompatible types when returning type ‘const char *’ but ‘sp_RbVal’ was expected` (for the `build` and `one` lines).

The generic class-method dispatch on a dynamic Class value in `codegen_call.c` claims the `new` call as soon as some class defines `self.new`: it has no arm for classes that construct normally, and types the result from the user `self.new` methods alone (here `String`), so the boxed result slot is assigned a C string. When it does not claim the call, the `new` dispatches build every class with its constructor and never consult a user `self.new`.
