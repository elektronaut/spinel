title: `super` in a method called on a poly receiver looks for the parent's `m#pf` and fails

When a method that takes an anonymous `&` (`def m(x, &) = super`), or one that yields, is called on a receiver that can be one of several classes, a `super` in its body can't find the parent's method. It raises `NoMethodError` naming `m#pf`, or, when the parent is itself such a method, the C build fails. The same calls on a receiver of a single known class work.

```ruby
class P
  def m(x) = "P#{x}"
end
class Q < P
  def m(x, &) = super
end
[P, Q].each { |k| p k.new.m(1) }
```

CRuby prints `"P1"`, `"P1"`. Spinel prints `"P1"`, then raises `super: no superclass method 'm#pf' for an instance of Q (NoMethodError)`.

With a three-level chain, the build fails instead:

```ruby
class P
  def m(x) = "P#{x}"
end
class Q < P
  def m(x, &) = super
end
class R < Q
  def m(x, &) = "R" + super
end
[P, R].each { |k| p k.new.m(1) }
```

CRuby prints `"P1"`, `"RP1"`. Spinel fails the C build with `error: void value not ignored as it ought to be` on the `"R" + super` line.

A method like this reached through a poly dispatch runs as its proc-form clone `m#pf` (`make_yield_proc_forms`). A `super` in the clone resolves the parent method from the scope's name: `comp_prep_user_name` in `src/compiler.c` strips only a prepend prefix, and `emit_super_inline` in `src/codegen.c` passes `s->name` unchanged to the chain lookup. So both look for `m#pf`, which no parent that doesn't yield has.
