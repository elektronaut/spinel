title: A splat followed by more positional arguments binds the wrong parameters when the method has keywords, or is called on an instance

A call can splat an array and then pass more positional arguments after it (`f(*a, 3)`), and which parameter the 3 fills depends on the array's length. Spinel gets this right for a plain method, but when the method also has a keyword parameter, the trailing argument is dropped or lands in the wrong parameter. Calls to an instance method go wrong the same way even without keywords: the trailing argument is dropped, and too many arguments raise nothing.

```ruby
def kw(a, b = 0, k: 1) = "kw(#{a.inspect},#{b.inspect},#{k})"
puts kw(*[1], 2, k: 3)
puts kw(*[], 2, k: 3)
def rk(a, b = 0, k:) = "rk(#{a.inspect},#{b.inspect},#{k})"
puts rk(*[1], 2, k: 3)
```

CRuby prints `kw(1,2,3)`, `kw(2,0,3)`, `rk(1,2,3)`. Spinel prints `kw(1,0,3)`, `kw(nil,0,3)`, `rk(1,0,3)`.

Through an instance method:

```ruby
class O
  def m(a, b) = "m(#{a},#{b})"
  def o(a, b = 0, c = 0) = "o(#{a},#{b},#{c})"
end
puts O.new.o(*[1], 3)
puts O.new.m(*[1, 2], 3)
```

CRuby prints `o(1,3,0)` and then raises `wrong number of arguments (given 3, expected 2) (ArgumentError)`. Spinel prints `o(1,0,0)`, `m(1,2)`.

`emit_args_filled` in `src/codegen_fold.c` gathers all the positionals of such a call into one array and binds from it (f09820a5), but refuses to when the method has a keyword parameter or the call has a keyword hash, and then falls back to a layout that assumes the splat fills exactly the gap before the trailing argument. `opt_before_required` also reads `def rk(a, b = 0, k:)` as having an optional before a required parameter, because `nrequired` counts the required keyword, which refuses the gather as well. `emit_dispatch`, the instance-call path, has no gather at all.
