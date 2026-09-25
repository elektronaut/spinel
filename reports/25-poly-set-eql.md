# 25-poly-set-eql (frosted-shrike) — report

**Branch:** `fix-poly-array-set-eql` (on upstream/master f9739163)
**Commit:** `189d7be2` — "Array set operations match elements by eql?, not =="
**Diff stat:**  3 files changed, 47 insertions(+), 5 deletions(-)

## Root cause

`sp_PolyArray_difference`, `_union`, `_intersect` and `_intersect_p` (lib/spinel_rt.h)
tested membership through `sp_PolyArray_include_val`, which compared with
`sp_poly_eq` (`==`, coercing Integer against Float). Ruby matches set-operation
elements by hash/`eql?`, so `2` and `2.0` are different elements. That helper had
no other callers; it is now `sp_PolyArray_include_eql` over `sp_poly_eql`.

## Sibling paths checked

- Fixed by the same change (wrong before): the method forms
  (`difference`/`union`/`intersection`/`intersect?`), an Integer array against
  a Float array (`[1,2,3] - [2.0,3.0]` etc., both directions), and nested arrays
  (`[[1, 2]] - [[1, 2.0]]`).
- Already correct on master: `uniq`, Hash with mixed Integer/Float keys
  (`h[2]` vs `h[2.0]`, `key?`, `merge`), `include?`/`index`/`count` (these are
  `==` in Ruby), `tally`, `group_by`.

Test: `test/poly_array_set_eql.rb` (checked against CRuby).

## Gate

`LANG=C.UTF-8 make -k -j4 gate TEST_JOBS=-j4`:

```
Tests: 4009 pass, 2 fail, 0 error
FAIL: pkg.tmpdir.tmpdir_expand_usable        (known: root)
FAIL: socket_ipv6_and_class_methods          (known: no UDP)
rubyspec-gate[language]: all 671 expected-PASS examples still pass
rubyspec-gate[core/array]: all 421 expected-PASS examples still pass
rubyspec-gate[core/string]: all 571 expected-PASS examples still pass
rubyspec-gate[core/hash]: all 192 expected-PASS examples still pass
rubyspec-gate[core/integer]: all 171 expected-PASS examples still pass
rubyspec-gate[core/range]: all 83 expected-PASS examples still pass
Benchmarks: 62 pass, 0 fail, 0 error, 0 skip
spin-e2e: ALL GREEN
```

## Surprising

Nothing beyond the typed Integer/Float arrays sharing the bug: they are routed
through the PolyArray helpers, so the one fix covers them.
