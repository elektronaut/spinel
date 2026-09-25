title: Storing a helper's array into an ivar an RBS seed pins to `Array[Integer]` fails the C build when the helper only sees an empty `[]` default

With an RBS seed that declares an ivar `Array[Integer]` (`@storage: Array[Integer]`), assigning it the result of a helper that is only ever handed an empty `[]` default (here because the only caller is a subclass's bare `super`) produces C that doesn't compile. Inference types the helper's result as a general Array, and the seed stops the ivar from widening to match.

The seed, in `sig/mem.rbs`:

```rbs
class Mem
  @storage: Array[Integer]
end
```

The program, compiled with `spinel --rbs sig seeded_empty_default.rb`:

```ruby
class Mem
  def initialize(initial = [])
    @storage = fill(initial)
  end

  def [](i) = @storage[i]

  private

  def fill(initial)
    array = initial.dup
    0.upto(3) { |i| array[i] ||= 0 }
    array
  end
end

class Recording < Mem
  def initialize
    super
    @log = []
  end
end

p Recording.new[2]
```

CRuby prints `0`. Spinel fails the C build: `seeded_empty_default.rb:3: error: assignment to ‘sp_IntArray *’ from incompatible pointer type ‘sp_PolyArray *’ [-Werror=incompatible-pointer-types]`.

The ivar store in `src/codegen_stmt.c` converts the value into a typed array slot only when the value is boxed (`comp_ntype == TY_POLY`). A value typed as another array kind, here an `sp_PolyArray *`, is written into the `sp_IntArray *` slot as a raw pointer. The value-position store and both forms of `@x ||= v` in `src/codegen_expr.c` and `src/codegen_stmt.c` have the same gap.
