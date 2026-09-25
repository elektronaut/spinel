title: `super` from a method with an anonymous `&` doesn't pass the block to a parent that keeps it

When an override takes an anonymous block (`def on(tag, &)`) and calls `super` into a parent that stores its block as `&handler`, the parent receives `nil` instead of the block. This happens with a bare `super`, with `super(tag, &)` and with `super(tag)`, and also when the override yields instead of taking `&`. A later call to the stored handler fails.

```ruby
class Base
  def on(tag, &handler) = @handler = handler
  def fire(v) = @handler.call(v)
end
class A < Base
  def on(tag, &) = super
end
a = A.new
a.on(:x) { |v| p v }
a.fire(3)
```

CRuby prints `3`. Spinel raises `undefined method 'call' for nil (NoMethodError)`.

A method with an anonymous `&`, or one that yields, has no proc of its own and is spliced at its call sites. `emit_super_block_arg` in `src/codegen.c` only passes a block to the parent when the caller has a named `&blk` proc, and passes `NULL` otherwise.
