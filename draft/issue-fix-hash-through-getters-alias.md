title: An index write through a local holding a getter's hash is typed apart from the ivar, and the C build fails

A class fills an ivar hash with one key type (`@c[k] = v` called with Integers) and exposes it through a getter (`def cache = @c`). When the caller copies the getter's result into a local and writes a different key type through that local (`x = c.cache; x["x"] = "y"`), the generated C does not compile. The local and the ivar are the same hash, but Spinel types them separately.

```ruby
class C
  def initialize = @c = {}
  def put(k, v) = @c[k] = v
  def cache = @c
end
c = C.new; c.put(1, 2); x = c.cache; x["x"] = "y"; p c.cache
```

CRuby prints `{1 => 2, "x" => "y"}`. Spinel fails to build the C: `error: assignment to 'sp_StrStrHash *' from incompatible pointer type 'sp_IntIntHash *'`.

`infer_write_types` in `src/analyze_pass.c` folds the index write into the local's own type only, so `x` becomes String-keyed while the ivar it was assigned from stays Integer-keyed, and the assignment `x = c.cache` no longer type-checks. A write straight through the getter (`c.cache["x"] = "y"`) is already taken as evidence for the ivar; the same write through a local alias is not.
