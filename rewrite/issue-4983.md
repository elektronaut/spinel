Array set operations (`-`, `|`, `&` and their method forms `difference`, `union`, `intersection`, `intersect?`) treat an Integer and an equal Float as the same element, so `[1, 2, "y"] - [2.0]` removes the `2`. Ruby matches set-operation elements by `hash`/`eql?`, where `2` and `2.0` are different. The result is a silently wrong array, in a mixed array, between an Integer array and a Float array, and inside nested arrays.

```ruby
a = [1, 2, "y"]
p a - [2.0]
p a | [2.0]
p a & [2.0]
```

CRuby prints `[1, 2, "y"]`, `[1, 2, "y", 2.0]`, `[]`. Spinel prints `[1, "y"]`, `[1, 2, "y"]`, `[2]`.

The same happens between an Integer array and a Float array:

```ruby
b = [1, 2, 3]
f = [2.0, 3.0]
p b - f
p b | f
p b & f
```

CRuby prints `[1, 2, 3]`, `[1, 2, 3, 2.0, 3.0]`, `[]`. Spinel prints `[1]`, `[1, 2, 3]`, `[2, 3]`.

`sp_PolyArray_difference`, `sp_PolyArray_union`, `sp_PolyArray_intersect` and `sp_PolyArray_intersect_p` in `lib/spinel_rt.h` test membership through `sp_PolyArray_include_val`, which compares with `sp_poly_eq` (`==`, coercing Integer against Float) rather than `eql?`. Typed Integer and Float arrays are routed through the same helpers.
