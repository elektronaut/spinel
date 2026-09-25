A Struct built with a splat (`S.new(*args)`) gets wrong member values when another call site builds the same Struct with Integer arguments (`S.new(1, 2)`). A String that arrives through the splat comes out as a large garbage number, and a member the splat array is too short to fill comes out as `0` instead of `nil`. There is no error; the program just prints the wrong values.

```ruby
S = Struct.new(:x, :y)
S.new(1, 2)
def mks(*args) = S.new(*args)
p mks(5)
p mks(5, "t")
```

CRuby prints `#<struct S x=5, y=nil>` and `#<struct S x=5, y="t">`. Spinel prints `#<struct S x=5, y=0>` and `#<struct S x=5, y=94308753727545>` (the number changes from run to run).

`struct_new_types_members` in `src/analyze_pass.c` treats the `SplatNode` in `S.new(*args)` as a single positional argument, so it does not widen the members the splat can reach. The members keep the Integer type from `S.new(1, 2)`, and the splat's run-time elements (a String, or the nil fill for a short array) are unboxed into Integer slots.
