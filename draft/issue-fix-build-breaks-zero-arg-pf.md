title: A yielding method with parameters reached only through a zero-argument poly call breaks the C build

When a receiver can be one of several classes, a method is called on it with no arguments and a block, and some classes' versions of that method take parameters and yield, the generated C doesn't compile. CRuby raises `ArgumentError` for the classes whose method needs arguments and runs the others.

```ruby
class A
  def w(x) = yield(x)
end
class B
  def w = yield(:b)
end
class C
  def w(x, y) = yield(x, y)
end
[A.new, B.new, C.new].each do |o|
  p o.w { |v| [:blk, v] }
rescue ArgumentError => e
  p e.message
end
```

CRuby prints `"wrong number of arguments (given 0, expected 1)"`, `[:blk, :b]`, `"wrong number of arguments (given 0, expected 2)"`. Spinel fails to build the C: `error: incompatible types when initializing type 'sp_int' {aka 'long int'} using type 'sp_RbVal'` (three times, in the proc forms `sp_A_w_pf` and `sp_C_w_pf`).

`make_yield_proc_forms` (`src/analyze.c`) types an untyped parameter of a yielding method's proc form as poly, but the fixpoint's re-narrow reset turns every poly parameter back to unknown each round. No call site passes arguments to `w`, so nothing widens those parameters again, and the proc form reads its boxed argument slots as `sp_int`.
