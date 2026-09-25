title: A zero-argument call on a poly receiver whose method needs arguments raises NoMethodError instead of ArgumentError

When a receiver can be one of several classes and a method is called on it with no arguments, a class whose method needs arguments gets no dispatch arm, so the call raises `NoMethodError` instead of CRuby's `ArgumentError`. This happens for any required parameter (`def h(x)`, `def t(*r, x)`), and also when a leading optional parameter comes before a required one, as in `def h(a = {}, c)`. A method reopened on `Object` with a required parameter (`class Object; def zz(x)`) called through a poly value behaves the same way.

```ruby
class A
  def h(a = {}, c) = [:A, a, c]
end
class B
  def h(a = {}, c) = [:B, a, c]
end
[A.new, B.new].each do |o|
  begin
    p o.h
  rescue ArgumentError => e
    p e.message
  end
end
```

CRuby prints `"wrong number of arguments (given 0, expected 1..2)"` twice. Spinel raises `undefined method 'h' for an instance of A (NoMethodError)`, which the `rescue ArgumentError` doesn't catch.

The zero-argument path of `emit_poly_method_dispatch` in `src/codegen_call.c` keeps a class's arm only when the method's `nrequired` is 0. Any method that needs arguments is dropped, and so is `def h(a = {}, c)`, because `nrequired` is an index rather than a count (2 there). The call then falls through to the switch's default, which answers `NoMethodError`. The argument form of the same dispatch already judges counts with `poly_arm_count` (#4958).
