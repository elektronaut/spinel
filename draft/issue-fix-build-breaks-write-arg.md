title: Passing a write to a mutable-string local as an argument, `show(buf = +"abc")`, breaks the C build

When a call's argument is an assignment to a local that is later mutated (`show(buf = +"abc")` followed by `buf << "d"` in a block), the generated C doesn't compile. A plain `show(+"xy")` and a write to an ordinary string local, `show(t = "zz")`, both work.

```ruby
def show(s) = s.length
buf = nil
n = show(buf = +"abc")
3.times { buf << "d" }
p [n, buf]
```

CRuby prints `[3, "abcddd"]`. Spinel fails to build the C: `error: initialization of 'sp_String *' from incompatible pointer type 'const char *'` (the generated `sp_String * _t2 = _t1;`, where `_t1` is a `const char *`).

The analyzer types `show`'s parameter from the argument, and for a write that's the local's own type, a mutable-string handle (`sp_String *`). Codegen emits the write through its String value form, though, so the argument hoist in `emit_args_filled` (`src/codegen_fold.c`) declares a `const char *` temp and hands it to the `sp_String *` parameter.
