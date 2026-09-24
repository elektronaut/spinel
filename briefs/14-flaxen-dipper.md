status: claimed
branch: fix-array-new-block-string-local

# flaxen-dipper

Low priority.

## flaxen-dipper

, low priority: `Array.new(n) { }` with a `+""` local mutated in a nested block gives a C error (sp_String* from const char*).

- `14-flaxen-dipper/r9.rb` (CRuby 4.0 output in `r9.rb.expected`)

