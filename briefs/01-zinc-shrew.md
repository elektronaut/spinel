status: done
branch: fix-poly-recv-default-ivar

# zinc-shrew: poly-receiver arm with an ivar default emits a mis-parenthesized cast

A poly-receiver dispatch arm evaluating an ivar default emits
`(sp_B *)x->iv_extra`. The cast binds looser than `->`, so the generated C
doesn't compile.

```ruby
class A
  def initialize = @k = 1
  def m(x, y = @k) = [x, y]
end
class B < A
  def initialize = @extra = 7
  def m(x, y = @extra) = [x, y]
end
class Caller
  def initialize(o) = @o = o
  def go = @o.m(2)
end
p Caller.new(B.new).go
p Caller.new(A.new).go
```

Expected output (CRuby):

```
[2, 7]
[2, 1]
```

Hints: the default-arg expression is emitted inside the poly dispatch arms
(`src/codegen_call.c`, near `emit_poly_method_dispatch`). Fix it where the
receiver is cast; don't post-process strings. Test variants to add: a default
that calls a method on the ivar, and a three-class hierarchy.
