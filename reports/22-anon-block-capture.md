# anon-block-capture (ashen-plover): report

**Status:** done
**Branch:** `fix-anon-block-capture-cells` (based on upstream/master `ab41b4ae`)
**Commit:** `2b3f56be` "An anonymous & is a named block parameter to the analysis"

## Root cause

`analyze.c` marked every method with an anonymous `&` as `yields` ("always
safe to inline"). It skipped the escape and forward analysis that a named
`&blk` gets, because that analysis follows `LocalVariableReadNode`s of the
param's name, and an anonymous forward (`BlockArgumentNode` with no
expression) has none. So `def install(&) = R.set(&)` was always spliced into
its caller. The caller's literal block was then turned into a proc inside the
splice, and its captures of the caller's locals were copied by value: the
proc declared its own `lv_total = 0`, and the writes were lost.

## Fix: the brief's suggested direction

A new desugar pass, `desugar_anon_block_param` (`analyze_desugar.c`), runs
before any scope is built, just after `desugar_forwarding_to_rest_callee`. It
names an anonymous block param `__anon_block`, mirroring `__anon_kwrest` for
`**`. It also rewrites every anonymous `&` forward in that method's own body
(blocks and lambdas included; nested def/class/module excluded) into
`&__anon_block`. From then on the named machinery decides. A forward into a
method that keeps the block is no longer inlined. `install` becomes a real
`sp_rb_install(sp_Proc *const lv___anon_block)`. The literal block is built as
a proc at the call site, and `total` is celled (`_cell_total`). A forward into
a yield-inlined callee still inlines, as before.

`Method#parameters` maps the synthetic name back to `:&`, as CRuby reports it.
On master, taking a Method of such a method didn't compile at all: there was
no function to point at.

I checked the existing special cases for anonymous `&`. `fwd_drop_spent_anon_block_param`
(#4625) already handles the named case generally. The `blk_param[0] == 0`
branches (analyze.c ~14723, ~15822, the each materializer) are now
unreachable for a `def`, but I left them in place. All 14 existing tests that
use an anonymous `&` pass unchanged.

## Diff stat

```
 src/analyze.c                                      |  1 +
 src/analyze_desugar.c                              | 64 +++++++++++++++++++++
 src/analyze_internal.h                             |  1 +
 src/codegen_call.c                                 |  5 +-
 test/anon_block_capture_cells.rb                   | 17 ++++++
 test/anon_block_capture_cells.rb.expected          |  1 +
 test/anon_block_capture_cells_variants.rb          | 67 ++++++++++++++++++++++
 test/anon_block_capture_cells_variants.rb.expected |  7 +++
 8 files changed, 162 insertions(+), 1 deletion(-)
```

Tests:

- `test/anon_block_capture_cells.rb` is the brief's reproducer.
- `test/anon_block_capture_cells_variants.rb` covers:
  - an ivar read and write in a block stored through `&` (an ivar receiver);
  - an implicit-self call in the block;
  - two levels of anonymous forwarding (Hub → Bus → Register);
  - two captured locals written by a stored block called twice;
  - a captured array mutated through two levels;
  - `#parameters` of an anonymous-`&` method;
  - `block_given?` through an anonymous forward.

Both match CRuby. Master refuses the variants file ("proc referencing an
uncaptured outer variable").

This branch alone also fixes cobalt-kestrel's reproducer (brief 02, `r21.rb`:
7) and brief 04's `test/anon_block_forward_capture.rb` (7 7 [10, 12] "got 1
2"), because the anonymous block is no longer spliced.

## Gate (`make -k -j4 gate TEST_JOBS=-j4`, `LANG=C.UTF-8`)

```
Tests: 4010 pass, 2 fail, 0 error
Benchmarks: 58 pass, 0 fail, 4 error, 0 skip   (in the gate; `make bench` alone: 62 pass, 0 error)
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

The two test failures are the known environment ones. The four benchmark
ERRs in the gate were `bm_ackermann`, `bm_ao_render`, `bm_attr_accessor` and
`bm_bigint_fib`: the alphabetically first batch, which hit the bench leg's
10 s compile timeout while the rest of the gate was starting. None of them
uses a block parameter. Rerun alone right after the gate, `make bench` gives
62 pass, 0 error. The same thing happened to `bm_ackermann` in brief 02's
gate. The timeout seems too tight for this container under `-j4`.

## Interaction with the unmerged neighbouring branches

This branch merges cleanly with each of `fix-new-block-forwarding` (brief 03),
`fix-anon-block-forward-capture` (brief 04), `fix-forwarded-block-ivar-write`
and `fix-forwarded-block-ivar-write-new` (brief 02).

- **Needs brief 03 for `Klass.new(&)`.** With the anonymous param now named,
  `def install(&) = @r = Reg.new(&)` fails the same way a named
  `Reg.new(&blk)` does on master: `lv___anon_block` is undeclared at the
  stored-block initialize arm. On master, the anonymous form compiled but
  silently threaded NULL. So on this branch alone it's a loud failure instead
  of a silent one, and merging brief 03 (or brief 02's `-new` branch) fixes
  it. For the same reason, `super(&)` in an inlined method needs brief 02's
  `fix-forwarded-block-ivar-write-new`.
- **Briefs 03 and 02-`new` overlap.** Merged together, they conflict in
  `emit_class_new_call`: both made nearly the same `.new` fix. Take brief 03's
  hunk. The `super` half of 02-`new` (`emit_super_block_arg`) is unique to it.
- **Combined stack tested.** This branch + 03 + 04 + 02 + 02-`new`, with that
  conflict resolved toward 03, built in a scratch worktree. All seven related
  tests pass on it: `anon_block_capture_cells{,_variants}`,
  `new_block_forwarding`, `anon_block_forward_capture`,
  `forwarded_block_ivar_write{,_variants}` and
  `forwarded_block_stored_new_super`. I didn't gate the combination.
- **Brief 04 may be redundant.** Once this lands, brief 04's
  `a_scope_forwards_block_to_keeper` probably matters only for forwards this
  branch still inlines. Its test passes on this branch without it.

## Not done

- `#parameters` still omits an anonymous `*` / `**` entirely. That's
  pre-existing. CRuby reports `[:rest, :*]` and `[:keyrest, :**]`.
