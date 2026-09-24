# dusky-gadwall: report

**Status:** done
**Branch:** `fix-anon-block-forward-capture` (on origin, based on upstream/master `032c037a`)
**Commit:** `4b6259a6ae4d8b98b38719622d9d61f6198cd310`: "A block forwarded by an anonymous & to a method that keeps it cells its captures"

Commit author is `Claude <noreply@anthropic.com>`, not Inge. The README's
`git config user.name/email` step arrived mid-brief, after the commit, and the
session's permission classifier refused the `--amend --reset-author`. You may
want to re-author it before opening the PR.

## Root cause

The yield-inlining pass (`analyze.c`, around the `blk_fwd_callee` loop) always
marks an anonymous `&` method `yields=1`, because it has no name to escape
through. A named `&blk` forwarder whose callee keeps the block gets an escape
edge (#3772) and stays a real function, so `a_block_is_lifted` cells the
literal block's captures. The anonymous forwarder is spliced instead, and the
literal block lands on `bus.install(&)`, where codegen materializes it as a
proc. `mark_proc_captures` only knew one shape of "inlined forwarder whose
block still becomes a proc": the one forwarding to a POLY receiver
(`a_block_forwarded_into_poly`). So `box` never got a cell, and
`emit_proc_literal` refused the program.

## Fix

New `a_scope_forwards_block_to_keeper(c, mi, depth)`. For a yield-inlined
scope, it asks whether a `&`/`&blk` forward reaches a method that takes a real
named `&block` and isn't inlined. It follows inlined forwarders up to 4 links.
`a_block_forwarded_into_poly` now ORs it in and is renamed
`a_block_forwarded_to_proc`. Like the poly case, this only feeds capture
marking, not the inlining decision, so the anonymous forwarder is still
spliced.

## Tests

`test/anon_block_forward_capture.rb` (the expected output matches CRuby):
1. The brief's shape (endless `def install(&) = keeper.install(&)`), with a block reading a captured local.
2. The block writes a captured local (`total += value`).
3. Two anonymous forwarders in a row before the keeper.
4. An anonymous forward to a keeper on self (`install(&)` → `keep(&blk)`).

On unpatched master, 1 and 3 are refused. **Case 4 was a silent miscompile on
master:** it printed `"got"` where CRuby prints `"got 1 2"`, because the
block's writes went to a by-value copy. h.rb, i.rb and k.rb from the brief all
print `7` now.

## Diff stat

```
 src/analyze.c                               | 68 +++++++++++++++++----
 test/anon_block_forward_capture.rb          | 91 +++++++++++++++++++++++++++++
 test/anon_block_forward_capture.rb.expected |  4 ++
 3 files changed, 151 insertions(+), 12 deletions(-)
```

## Gate (`LANG=C.UTF-8 make -k -j4 gate TEST_JOBS=-j4`, on the rebased commit)

```
Tests: 3996 pass, 2 fail, 0 error      (pkg.tmpdir.tmpdir_expand_usable: root; socket_ipv6_and_class_methods: no UDP; both fail on master too)
Benchmarks: 62 pass, 0 fail, 0 error, 0 skip
Optcarrot: OK
infer-test: pass
spin-e2e: ALL GREEN
rubyspec-gate[language]: all 671 expected-PASS examples still pass
rubyspec-gate[core/array]: all 421 expected-PASS examples still pass
rubyspec-gate[core/string]: all 571 expected-PASS examples still pass
rubyspec-gate[core/hash]: all 192 expected-PASS examples still pass
rubyspec-gate[core/integer]: all 171 expected-PASS examples still pass
rubyspec-gate[core/range]: all 83 expected-PASS examples still pass
```

An earlier run on `70b2be32` without `LANG` showed 2 benchmark ERRs
(bm_attr_accessor, bm_binary_trees). They pass when run alone and in the
rerun, so the cause was load timeouts.

## Surprising / not fixed here

- **Related to 02 (cobalt-kestrel):** `r21.rb` still prints `0` with this fix.
  That block writes an **ivar**, not a local, so capture cells aren't
  involved. It's most likely the proc's `self` when it's materialized inside
  the spliced anonymous forwarder. This fix doesn't cover it; 02's session
  owns it.
- **A separate pre-existing drop:** a *named* `&blk` forwarder into an
  *anonymous* forwarder into a keeper loses the block completely ("undefined
  method 'call' for nil"), with no captures involved:

  ```ruby
  class Keeper; def install(&h) = @h = h; def fire(v) = @h.call(v); end
  class Front; def initialize = @k = Keeper.new; def install(&) = @k.install(&); def fire(v) = @k.fire(v); end
  class Outer; def initialize = @f = Front.new
    def install(&blk) = @f.install(&blk); def fire(v) = @f.fire(v); end
  o = Outer.new; o.install { |v| p v * 2 }; o.fire(5)   # CRuby 10
  ```

  Named → named and anonymous → anonymous both work. The mixed shape
  inline-splices a named forward into an anonymous one, and the anonymous `&`
  inside the nested splice doesn't resolve back to the outer literal block.
  See `resolve_forwarded_block` / `g_block_param_name` in `codegen_fold.c`,
  and the #4618 note in `codegen_iter.c` saying named forwards are normally
  rewritten by `desugar_value_callable_forwards` first. This is a candidate
  for its own brief.
- Without `LANG=C.UTF-8`, the rubyspec gate is vacuous (as the README now says).
