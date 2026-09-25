When a program defines a top-level method and later defines it again with `def`, Spinel binds every call to the first definition, while CRuby runs the definition in effect when the call happens. If the two definitions take different arguments, calls meant for the second one are refused. If they take the same arguments, the generated C doesn't compile.

A redefinition with a different arity, called after the second `def`:

```ruby
def tw(&b) = [:first]
def tw(a)
  a.each { |x| yield x }
  [:second]
end
p tw([1]) { |x| x }
```

CRuby prints `[:second]`. Spinel raises `wrong number of arguments (given 1, expected 0) (ArgumentError)`.

A redefinition with the same arity:

```ruby
def pick = :one
def pick = :two
p pick
```

CRuby prints `:two`. Spinel fails the C build with `error: redefinition of ‘sp_pick’`.

`comp_method_index_direct` in `src/compiler.c` returns the first top-level scope with the name, and the frozen method index is built so the lowest scope index wins, so calls resolve to the first `def`. Both definitions are also emitted as C functions with the same name. Methods redefined inside a class aren't affected: `comp_method_in_class` takes the last definition and `scope_is_shadowed` skips the earlier ones.
