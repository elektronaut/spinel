title: A block that calls the method's `&handler`, passed to a block-keeping method on an ivar receiver, fails the C build with `_cell_handler` undeclared

A method that takes `&handler` and hands a literal block reading `handler` to a method that stores its own block (`@reg.set { |v| handler.call(v) }` inside `def install(&handler)`) fails to compile when the receiver is an instance variable set in the same method. The same happens with a local assigned from `Reg.new`.

```ruby
class Reg
  def set(&h) = @h = h
  def poke(v) = @h.call(v)
end
class Bus
  def install(&handler)
    @reg = Reg.new
    @reg.set { |v| handler.call(v) }
  end
  def poke(v) = @reg.poke(v)
end
b = Bus.new
b.install { |v| puts v }
b.poke(7)
```

CRuby prints `7`. Spinel fails the C build with `error: '_cell_handler' undeclared (first use in this function)`.

The pass in `analyze_program` (`src/analyze.c`) that decides whether `install` can be yield-inlined asks `a_block_is_lifted` whether the block becomes a real proc, and that resolves the callee through `infer_type(recv)`, but `@reg` has no type yet at that point. The block counts as spliced, `install` is inlined with no storage for `handler`, and codegen, working on settled types, lifts the block and references `_cell_handler`.
