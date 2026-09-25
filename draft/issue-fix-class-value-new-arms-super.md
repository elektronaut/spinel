title: `super` inside `def self.new` raises "no superclass method 'new'" instead of calling Class#new

A class that overrides `self.new` and calls `super` from it, to adjust the arguments before the normal construction, raises NoMethodError on Spinel. In Ruby that `super` is `Class#new`: it allocates the receiving class and runs its `initialize`.

```ruby
class C
  def self.new(x) = super(x * 10)
  def initialize(x) = @x = x
  def to_s = "C(#{@x})"
end
c = C.new(7)
puts c
```

CRuby prints `C(70)`. Spinel raises `super: no superclass method 'new' for C (NoMethodError)`. Writing `puts C.new(7)` directly is refused at compile time instead: ``unsupported puts argument: node 32 (CallNode `new`) recv=ConstantReadNode/ty49 argc=1 arg0ty3``.

A related shape: a `self.new` inherited by a subclass and reading the receiving class (here through `name`) does not compile when called on the subclass.

```ruby
class N
  def self.new(x) = "#{name}:#{x}"
end
class M < N; end
puts M.new(2)
```

CRuby prints `M:2`. Spinel fails in the C compiler: `error: too few arguments to function ‘sp_N_s_new__m’`.

`emit_super` (`codegen.c`) resolves `super` in a class method only through the parent's class-method chain, and with no class method `new` above it falls back to the NoMethodError; the analyzer likewise leaves the call untyped. For the second shape, the two static `K.new` sites in `codegen_call.c` that call a user `self.new` pass no receiving class, although the method takes one when its body reads it.
