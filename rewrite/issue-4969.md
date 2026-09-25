A call that passes more positional arguments than the callee has positional parameters runs instead of raising `ArgumentError` when the callee also declares a keyword parameter or a `**kw`. `def m(x, k: 1)` called as `m(3, 4)` binds `x` to 3 and drops the 4, on the direct call and on an instance call alike. A related shape goes wrong the other way: a braceless keyword hash whose key names no parameter, as in `g(1, j: 2)` against `def g(x, y = 7, k: 1)`, is bound positionally to `y` instead of being refused as an unknown keyword.

A surplus positional into a callee with a keyword parameter, called directly and on an instance.

```ruby
class Kw
  def m(x, k: 1) = [x, k]
end
def m(x, k: 1) = [x, k]
p((m(3, 4) rescue $!.message))
p((Kw.new.m(3, 4) rescue $!.message))
```

CRuby prints `"wrong number of arguments (given 2, expected 1)"` twice. Spinel prints `[3, 1]` twice.

A surplus positional into a callee with `**kw`.

```ruby
def f(x, **kw) = [x, kw]
p((f(3, 4) rescue $!.message))
```

CRuby prints `"wrong number of arguments (given 2, expected 1)"`. Spinel prints `[3, {}]`.

A keyword hash with an unknown key, into a callee that declares keywords and has an optional positional.

```ruby
def g(x, y = 7, k: 1) = [x, y, k]
p((g(1, j: 2) rescue $!.message))
```

CRuby prints `"unknown keyword: :j"`. Spinel prints `[1, {j: 2}, 1]`.

The arity check in `emit_args_filled` (`src/codegen_fold.c`) counts keyword parameters as positional slots because they share `pnames[]` with the positional ones, skips any callee with `**kw`, and treats a keyword hash none of whose keys names a parameter as the positional options hash even when the callee declares keywords. The instance path in `emit_dispatch` keeps its own copy of the count with the same slot error, and skips every call that carries a keyword hash.
