title: A block passed through an anonymous `&` to a method that stores it loses its writes to the caller's locals

A block that writes a local of its caller, passed through a method with an anonymous block parameter (`def install(&) = R.set(&)`) to a method that stores it, updates a copy of the local instead of the local itself. When the stored block is called later, its writes never reach the caller, and the program silently prints the old value. The same program with a named `&blk` in `install` works.

```ruby
class Reg
  def set(&h) = @h = h
  def poke(v) = @h.call(v)
end
R = Reg.new
def install(&) = R.set(&)
total = 0
install { |v| total += v }
R.poke(3)
R.poke(4)
p total
```

CRuby prints `7`. Spinel prints `0`.

`analyze.c` marks every method with an anonymous `&` as `yields`, so it's always inlined into its caller. It skips the escape analysis a named `&blk` gets, which follows the reads of the parameter's name, and an anonymous forward has none. Inside the splice the caller's block becomes a proc whose captured locals are copied by value rather than shared through cells.
