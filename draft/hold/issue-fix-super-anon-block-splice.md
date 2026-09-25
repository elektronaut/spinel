title: `super(&)` into a yielding parent drops the block, and the parent's yields do nothing

When an override passes its anonymous block on with `super(&)` to a parent method that yields, the parent's yields run nothing if the override is itself spliced at the call site. That is the case when it's called with a literal block on a receiver of a single class, or when it's reached through a poly dispatch.

Called on a receiver that can be one of two classes, only the class using a bare `super` runs the block:

```ruby
class PfBase
  def each_twice
    yield 1
    yield 2
  end
end
class PfA < PfBase
  def each_twice(&) = super(&)
end
class PfB < PfBase
  def each_twice(&) = super
end
[PfA, PfB].each do |k|
  o = k.new
  o.each_twice { |x| p x * 10 }
end
```

CRuby prints `10`, `20`, `10`, `20`. Spinel prints only `10`, `20`.

Called directly on a single class, nothing runs:

```ruby
class Base
  def each_twice
    yield 1
    yield 2
  end
end
class Anon < Base
  def each_twice(&) = super(&)
end
Anon.new.each_twice { |x| p x * 10 }
```

CRuby prints `10`, `20`. Spinel prints nothing.

`emit_super_inline` in `src/codegen.c` splices the parent's yielding body in place of the `super`. It forwards the block being spliced only for a bare `super`, where the call has no block node. For `super(&)` it takes the `BlockArgumentNode` itself as the block to splice, so each `yield` comes out as a no-op.
