title: A yielding method called with a block runs with the wrong number of arguments instead of raising ArgumentError

A top-level method that yields, called with a block (`y1 { }` on `def y1(x) = yield(x)`), doesn't check how many arguments the call passes. A missing positional runs with a zero value and a surplus one is dropped, where CRuby raises `ArgumentError`. The same call without a block raises as it should. A `**kw` parameter on such a method is also bound wrongly: its keywords are lost, and a surplus positional breaks the C build.

```ruby
def y1(x) = yield(x)
begin
  y1 { |v| p v }
rescue ArgumentError => e
  p e.message
end
def y(x, k: 1) = yield(x + k)
begin
  y(1, 2) { |v| p v }
rescue ArgumentError => e
  p e.message
end
```

CRuby prints `"wrong number of arguments (given 0, expected 1)"`, `"wrong number of arguments (given 2, expected 1)"`. Spinel prints `0`, `3`.

A `**kw` parameter doesn't collect the call's keywords:

```ruby
def ykw(a, **kw) = yield(a, kw)
ykw(1, z: 2) { |a, kw| p [a, kw] }
```

CRuby prints `[1, {z: 2}]`. Spinel prints `[1, nil]`.

A surplus positional to a method with a `**kw` parameter:

```ruby
def ykw(a, **kw) = yield(a, kw)
begin
  ykw(1, 2) { |a, kw| p [a, kw] }
rescue ArgumentError => e
  p e.message
end
```

CRuby prints `"wrong number of arguments (given 2, expected 1)"`. Spinel fails the C build: `error: assignment to ‘sp_SymPolyHash *’ {aka ‘struct sp_SymPolyHash *’} from ‘long long int’ makes pointer from integer without a cast [-Werror=int-conversion]`.

`emit_inline_call_x` (`src/codegen_iter.c`), which inlines a yielding method at its call site, binds the parameters by walking them and reading the matching argument, with only the unknown-keyword check in front. Nothing compares the call's argument count with the method's, a `**kw` parameter binds its nil default, and a positional past the method's positionals is bound into the `**kw` slot.
