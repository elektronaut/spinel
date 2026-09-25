title: A leading optional before a *rest takes the argument meant for the required parameter after it

When a method has an optional parameter, then a `*rest`, then a required parameter (`def r(a = {}, *rest, c)`), a call that passes only enough arguments for the required parameter binds that argument to the optional as well. The required one gets it too, so the optional silently loses its default.

```ruby
def r(a = {}, *rest, c) = [a, rest, c]
p r(5)
p r(1, 5)
```

CRuby prints `[{}, [], 5]`, `[1, [], 5]`. Spinel prints `[5, [], 5]`, `[1, [], 5]`.

A keyword parameter after the post-rest parameters has a related problem: the keyword passed for it is ignored and it keeps its default.

```ruby
def kq(*r, c, k: 0) = [r, c, k]
p kq(1, k: 2)
```

CRuby prints `[[], 1, 2]`. Spinel prints `[[], 1, 0]`.

`arg_slot_for_param` in `src/codegen_fold.c` stops mapping as soon as the method has a `*rest` and falls back to binding by position, so the optional takes argument 0 even when the trailing required parameter needs it. Separately, the post-rest branch of `emit_args_filled` treats every parameter after the rest as a post, including a keyword that follows the posts.
