title: An index write through a subclass getter over an inherited ivar hash is not seen by the ivar's type

A base class keeps a hash in an ivar and fills it with one key type; a subclass exposes it through its own getter, and the caller writes a different key type through that getter. When the subclass getter is `def cache = super`, the generated C does not compile; when it reads the ivar itself (`def cache = @c`), the store raises TypeError at run time.

A getter that only calls `super`:

```ruby
class Base
  def initialize = @c = {}
  def cache = @c
  def put(k, v) = @c[k] = v
end
class Sub < Base
  def cache = super
end
s = Sub.new
s.put(1, 2)
s.cache["x"] = "y"
p s.cache
```

CRuby prints `{1 => 2, "x" => "y"}`. Spinel fails to build the C: `error: initialization of 'sp_int' {aka 'long int'} from 'char *' makes integer from pointer without a cast` on the `s.cache["x"] = "y"` line.

A subclass getter reading an ivar the base class writes:

```ruby
class Keeper
  def initialize = @c = {}
  def put(k, v) = @c[k] = v
end
class Shower < Keeper
  def cache = @c
end
k = Shower.new
k.put(1, 2)
k.cache[:k] = "v"
p k.cache
```

CRuby prints `{1 => 2, k: "v"}`. Spinel raises `cannot store a Symbol key with a String value into a hash Spinel typed as Integer-keyed with Integer values (the hash was not widened for this store) (TypeError)`.

`getter_ivar_targets` in `src/analyze_pass.c` only counts a method as a getter when its body ends in an ivar, so `def cache = super` is no getter and the write is evidence for nothing. When the getter does name the ivar, the write widens only the defining class's copy of the ivar's type, while the base class keeps its own narrower copy, and the post-fixpoint merge of the two leaves a hash the store cannot enter.
