status: done
branch: fix-silent-wrong-values

# silent-values

Two silent wrong values. Separate root causes; one branch each.

## rusty-nuthatch

static `S.new(*args)` where another site types a member Integer: a String element is unboxed as garbage and a short array nil-fills as 0 (silent wrong value); struct_new_types_members ignores splats

- `19-silent-values/gc3.rb` (CRuby 4.0 output in `gc3.rb.expected`)

## dun-shoveler

`puts` on a boxed value-type object ignores the user's `to_s`

- `19-silent-values/adv4.rb` (CRuby 4.0 output in `adv4.rb.expected`)

