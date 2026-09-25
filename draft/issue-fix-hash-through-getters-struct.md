title: A Struct member initialized with `{}` and written with mixed key types fails to compile

A Struct member is given an empty hash in the constructor (`S.new({})`), and the program then writes into it through the member reader with keys of different types (`s.h[1] = 2`, `s.h["x"] = "y"`). The generated C does not compile.

```ruby
S = Struct.new(:h)
s = S.new({})
s.h[1] = 2
s.h["x"] = "y"
p s.h
```

CRuby prints `{1 => 2, "x" => "y"}`. Spinel fails to build the C: `error: initialization of 'sp_PolyPolyHash *' {aka 'struct sp_PolyPolyHash *'} from incompatible pointer type 'sp_StrPolyHash *' {aka 'struct sp_StrPolyHash *'}` on the `S.new({})` line. The keyword form (`K.new(tbl: {}, n: 0)`) fails the same way.

The writes through the reader widen the member to the poly-keyed hash, but the `{}` argument is still built as an empty literal's own default variant, a String-keyed hash; `struct_new_types_members` in `src/analyze_pass.c` unifies the member's type with the argument's but never tells the literal which variant to build.
