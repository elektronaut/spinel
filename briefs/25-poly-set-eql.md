status: claimed
branch: fix-poly-array-set-eql

# poly-set-eql (handle: frosted-shrike). Silent wrong value.

PolyArray set operations (`-`, `|`, `&`) compare Integer and Float elements with
`==` instead of `eql?`/`hash`, so `2` and `2.0` count as the same element. Found by
the brief-18 session. The comparison is probably in
`sp_PolyArray_difference/union/intersect` in `lib/`. Check the typed-array and
Hash-key paths (`uniq`, `Hash#[]` with mixed Integer/Float keys) for the same mistake.

- `25-poly-set-eql/poly_set_eql.rb`
