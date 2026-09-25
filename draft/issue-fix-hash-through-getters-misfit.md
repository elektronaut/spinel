title: A direct Symbol-keyed write into an ivar hash filled through an `(@c ||= {})` getter fails to compile

A class creates its hash lazily in a getter (`def c = (@c ||= {})`) and writes to it both through the getter (`c[k] = v`) and directly (`@c[k] = v`). When the getter writes use Integer keys and a direct write uses a Symbol key with a Float value, the generated C does not compile.

```ruby
class C
  def c = (@c ||= {})
  def put_g(k, v) = c[k] = v
  def put_d(k, v) = @c[k] = v
end
o = C.new
o.put_g(1, 2)
o.put_d(:s, 3.5)
o.put_g(4, 5)
p o.c, o.c[1] + o.c[4], o.c[:s]
```

CRuby prints `{1 => 2, s: 3.5, 4 => 5}`, `7`, `3.5`. Spinel fails to build the C: `error: incompatible types when returning type 'sp_float' {aka 'double'} but 'sp_RbVal' was expected` in `sp_C_put_d`. The same happens without the final `put_g(4, 5)` call.

In `infer_write_types` (`src/analyze_pass.c`), the direct `@c[k] = v` write is passed to `fold_container_evidence` against the Integer-keyed type the getter writes already settled; the fold refuses the Symbol key and the write is silently dropped as evidence, so `put_d` is compiled against a hash that cannot hold what it stores. Writes through the getter already widen the ivar on such a misfit; the direct path does not.
