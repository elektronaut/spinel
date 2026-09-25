title: `replace` on an ivar an RBS seed pins to `Array[Integer]` raises NoMethodError when the source is a general Array

With an RBS seed that declares an ivar `Array[Integer]` (`@storage: Array[Integer]`), calling `@storage.replace(x)` where `x` is not itself typed an Integer array (here a helper's result that inference boxes) raises `NoMethodError` at run time. Without the seed the same program works, because the call widens `@storage` to a general Array.

The seed, in `sig/mem.rbs`:

```rbs
class Mem
  @storage: Array[Integer]
end
```

The program, compiled with `spinel --rbs sig replace_pinned.rb`:

```ruby
class Mem
  def initialize(initial = [])
    @storage = fill(initial)
  end

  def clear!(initial = [])
    @storage.replace(fill(initial))
  end

  def [](i) = @storage[i]

  private

  def fill(initial)
    array = initial.dup
    0.upto(3) { |i| array[i] ||= 0 }
    array
  end
end

m = Mem.new([7])
m.clear!([5, 6])
p m[0] + m[1]
```

CRuby prints `11`. Spinel raises `undefined method 'replace' for an instance of Array (NoMethodError)`.

The typed-array `replace` arm in `src/codegen_call_recv.c` only matches a source of the receiver's own array kind. Without a seed a source of another kind never reaches it, because the mutation widens the receiver, but the seed keeps `@storage` an IntArray while `fill(...)` is boxed, so no arm matches and the call falls through to the NoMethodError gate.
