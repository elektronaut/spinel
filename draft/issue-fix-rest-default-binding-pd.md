title: A default reading an earlier parameter fails to compile in a method with a *rest or a **kwrest

A parameter default can read an earlier parameter (`def g(u, v = u * 2)`), and Spinel handles that for a method with fixed parameters. When the method also has a `*rest` or a `**kwrest`, the generated C doesn't compile. This hits a keyword default that reads a positional or the rest, and an optional default next to a `**kw`.

```ruby
def m(n, *r, k: n + r.size) = k
p m(3, 1, 2)
```

CRuby prints `5`. Spinel's C build fails with `error: 'lv_n' undeclared (first use in this function)` (and the same for `lv_r`).

The same with a `**kwrest`:

```ruby
def h(x, y = 7, z = x * 2, **kw) = [x, y, z, kw]
p h(1, j: 2)
```

CRuby prints `[1, 7, 2, {j: 2}]`. Spinel's C build fails with `error: 'lv_x' undeclared (first use in this function)`.

A default is evaluated at the call site, so `emit_args_filled` in `src/codegen_fold.c` binds each argument to a call-site temp first and lets the default read the earlier parameter from it. That hoist is skipped for a method with a `*rest` or a `**kwrest`, so the default is emitted against the callee's `lv_n` / `lv_x`, which nothing at the call site declares. `emit_dispatch` (instance calls) and the poly receiver arm in `emit_poly_method_dispatch` (`src/codegen_call.c`) have the same restriction.
