title: A block passed on to `super` from an inlined method never reaches a parent that stores it

A subclass method that takes a block and hands it to `super`, where the parent method stores the block (`def on(&handler) = @handler = handler`), loses the block when Spinel inlines the subclass method into its caller. `super(&)`, a bare `super` and `super()` give the parent no block, so a later `@handler.call` raises NoMethodError. `super(&blk)` produces C that doesn't compile. The same forward into a storing `initialize` through `Klass.new(&)` is #4973.

The anonymous form:

```ruby
class Base
  def on(&handler) = @handler = handler
  def fire(v) = @handler.call(v)
end
class Anon < Base
  def on(&) = super(&)
end
a = Anon.new
a.on { |v| p v * 2 }
a.fire(21)
```

CRuby prints `42`. Spinel raises `undefined method 'call' for nil (NoMethodError)`.

The named form:

```ruby
class Base
  def on(&handler) = @handler = handler
  def fire(v) = @handler.call(v)
end
class Named < Base
  def on(&blk) = super(&blk)
end
n = Named.new
n.on { |v| p v * 2 }
n.fire(21)
```

CRuby prints `42`. Spinel fails to build the C: `named.rb:6: error: ‘lv_blk’ undeclared (first use in this function)`.

The implicit forms, a bare `super` and `super()`:

```ruby
class Base
  def on(&handler) = @handler = handler
  def fire(v) = @handler.call(v)
end
class Z < Base
  def on(&) = super
end
class P < Base
  def on(&) = super()
end
z = Z.new
z.on { |v| p [:zsuper, v] }
z.fire(1)
q = P.new
q.on { |v| p [:paren, v] }
q.fire(2)
```

CRuby prints `[:zsuper, 1]` and `[:paren, 2]`. Spinel raises `undefined method 'call' for nil (NoMethodError)` at the first `fire`, and the `super()` class alone fails the same way.

`emit_super_block_arg` in `src/codegen.c` reads the `super` call's block node as written and never resolves a forward to the block spliced in from the inlined method's caller. An anonymous `&` looks like no block, a named `&blk` emits the callee's own `lv_blk`, which the splice never declares, and an implicit `super` in an inlined body (`s->yields`) falls through to `NULL`.
