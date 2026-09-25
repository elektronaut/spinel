title: An override whose block is only yielded or checked with `.nil?` is skipped, and the parent's method runs instead

When a subclass overrides a method and the override takes a block it only yields to, or uses only through `blk.call`/`blk.nil?`, a call that dispatches on the receiver's class runs the parent's method for the subclass. Nothing is reported; the result is just the parent's.

```ruby
class A
  def m(x) = x + 1
  def run = m(1)
end
class C < A
  def m(x, &blk) = blk.nil? ? "C#{x}" : "blk"
end
p A.new.run
p C.new.run
```

CRuby prints `2`, `"C1"`. Spinel prints `2`, `2`.

The mirrored case, where the parent's method is the one using its block this way and the subclass overrides it with a plain method, goes wrong the same way.

```ruby
class F
  def m(x, &blk) = blk.nil? ? x + 1 : blk.call(x)
  def run = m(1)
end
class G < F
  def m(x) = x * 7
end
p F.new.run
p G.new.run
```

CRuby prints `2`, `7`. Spinel prints `2`, `2`.

Such a method is inlined at its call sites and has no C function of its own. The `cls_id` dispatch switch in `codegen_fold.c` keeps only arms whose method has a symbol (`scope_has_callable_symbol`), so it drops `C#m` and its `default:` runs `A#m`. In the mirrored case `emit_inline_call_x` (`codegen_iter.c`) splices the parent's body for every receiver without looking for an override.
