title: *nil into a rest parameter passes one nil, and a scalar splat in an instance call binds as an array

Splatting `nil` should pass no arguments, and splatting a non-array scalar should pass that one value. When `*nil` goes into a `*rest` parameter, Spinel passes a single `nil` instead. When a scalar is splatted into an instance method call (`O.new.m(*7)`), Spinel passes a one-element array instead of the value, or raises `TypeError`.

```ruby
def r(*xs) = xs.inspect
puts r(*nil)
puts r(1, *nil)
```

CRuby prints `[]`, `[1]`. Spinel prints `[nil]`, `[1, nil]`.

Through an instance method:

```ruby
class O
  def m(a, b = 0) = "m(#{a},#{b})"
  def g(x) = x + 1
end
puts O.new.m(*7)
puts O.new.g(*5)
```

CRuby prints `m(7,0)`, `6`. Spinel prints `m([7],0)` and then raises `no implicit conversion of Integer into Array (TypeError)`.

When `emit_rest_pack_kwh` in `src/codegen_fold.c` packs a rest, a statically nil splat operand takes the scalar branch and is pushed as one element; the suffix loop of `emit_rest_from_splat_and_argv` does the same. In `emit_dispatch`, the splat layout lowers only a poly or unknown operand through the splat's own normalization, so a nil or scalar operand is treated as if it were already an array. That is the gap #4898 closed in `emit_args_filled` for direct calls.
