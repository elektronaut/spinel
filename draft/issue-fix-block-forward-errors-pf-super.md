title: A method that forwards its block with `super(&)` raises `no superclass method 'on#pf'` on a poly receiver

When an override passes its anonymous block on with `super(&)` (`def on(&) = super(&)`) to a parent that keeps the block as `&handler`, and the method is called with a block on a receiver that can be one of several classes, the program raises `NoMethodError` at the `super`. Calling it on a receiver of a single known class works.

```ruby
class Base
  def on(&handler) = @handler = handler
  def fire(value) = @handler.call(value)
end
class A < Base
  def on(&) = super(&)
end
class B < Base
  def on(&) = super(&)
end
[A, B].each do |k|
  o = k.new
  o.on { |v| p [k.name, v] }
  o.fire(1)
end
```

CRuby prints `["A", 1]`, `["B", 1]`. Spinel raises `super: no superclass method 'on#pf' for an instance of A (NoMethodError)`.

A method with an anonymous `&` called with a block on a poly receiver runs as its proc-form clone `on#pf` (`make_yield_proc_forms`), and `super` inside the clone resolves its target from the scope's name (`emit_super` in `src/codegen.c`, and the `super` case of `infer_uncached` in `src/analyze_infer.c`), so it looks for `on#pf` in the parent chain. `Base#on` keeps its block rather than yielding, so it has no clone.
