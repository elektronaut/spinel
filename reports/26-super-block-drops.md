# super-block-drops: report

**Status:** done. The brief's two bugs are fixed, plus a third one they
depend on, which I found while testing. There are three root causes, so there
are three branches, each based on upstream/master `e25c617d`.

| Bug | Branch | Commit |
|---|---|---|
| coral-bunting | `fix-super-anon-block-bare` | `c539927c2e8bc567c44a18f7d3b4463cf337c355` |
| misty-heron | `fix-super-anon-block-splice` | `da29796b1077d05e7f83e428d1c2950270d19bec` |
| (new) `super` inside a `#pf` clone | `fix-super-anon-block-pf-name` | `928f576d7b512b0886a227bcc7559adf7374ca79` |

The brief's branch name `fix-super-anon-block` was only used locally.

**How the branches relate:**
- **Each branch stands alone.** Each branch's tests fail on master and pass
  with only that branch's fix. I checked every combination of the three fixes
  against every test.
- **They merge cleanly.** A three-way apply of all three onto master has no
  conflicts, and the result is byte-identical to the combined fix I tested.
- **Some programs need two of them.** A poly receiver calling an
  anonymous-`&` override whose bare `super` goes to a `&handler` parent needs
  both A and C.

## coral-bunting: a bare `super` from `def on(tag, &)` dropped the block

**Root cause.** A method with an anonymous `&`, or one that yields, is
inline-only: it is spliced at its call sites and has no proc of its own.
`emit_super_block_arg` handled only a caller with a real `&blk` proc, and passed
`NULL` otherwise. So the parent's `&handler` stored nil, and `.call` raised
`NoMethodError`.

**Fix** (`codegen.c`, 6 lines). When the caller is inline-only, `super` passes
the block being spliced (`emit_proc_literal(g_block_id)`, the same thing
`emit_method_call` does for a forwarded `inner(&)`). If no literal block is
being spliced, it passes the proc driving the splice (`g_yield_proc_ref`), and
otherwise `NULL`.

```
 src/codegen.c                                   |  6 +++
 test/super_anon_block_bare.rb                   | 10 +++++
 test/super_anon_block_bare.rb.expected          |  1 +
 test/super_anon_block_bare_variants.rb          | 52 +++++++++++++++++++++++++
 test/super_anon_block_bare_variants.rb.expected |  7 ++++
 5 files changed, 76 insertions(+)
```
The variants cover bare `super`, `super(tag, &)`, `super(tag)` (implicit block
passing), a yielding method calling `super`, a call with no block (the parent
sees nil), and a `&proc` caller.

## misty-heron: `super(&)` into a yielding ancestor did nothing

**Root cause.** When the method calling `super(&)` is itself spliced (a poly
dispatch arm, or a direct call with a block), `emit_super_inline` forwarded the
caller's block only for a bare `super`, where the block node is absent. For
`super(&)` it took the `BlockArgumentNode` as the block to splice into the
parent's yields, and each yield came out as `(void)(1LL)`. That's why only
PfB's pair printed.

**Fix** (`codegen.c`). A `BlockArgumentNode` now goes through
`resolve_forwarded_block`, like an inlined `inner(&)`. An anonymous `&`, or
`&blk` naming the method's own block, resolves to the block being spliced. A
forwarded real proc (`super(&PR)`) drives the parent's yields through that proc
instead.

```
 src/codegen.c                                     | 23 +++++++++++--
 test/super_anon_block_splice.rb                   | 16 +++++++++
 test/super_anon_block_splice.rb.expected          |  4 +++
 test/super_anon_block_splice_variants.rb          | 40 +++++++++++++++++++++++
 test/super_anon_block_splice_variants.rb.expected | 22 +++++++++++++
 5 files changed, 102 insertions(+), 3 deletions(-)
```
The variants cover `super(&)`, bare `super`, `super(&blk)`, a three-level
`super(&)` chain and `super(&CONST_PROC)`, each through both direct and poly
receivers, plus a `&proc` caller.

## New: `super` inside a proc-form clone looked up `m#pf`

**Root cause.** A method reached through a poly dispatch runs as its `m#pf`
clone. A `super` in the clone's body resolved the parent method by the scope's
name, `m#pf`, which no parent has, and it raised
`super: no superclass method 'm#pf'`. This fails the same way on master.
It came up as soon as the coral-bunting variants used a poly receiver.

**Fix.** `comp_prep_user_name`, which already maps a prepend shadow
(`__prep_N_m`) back to `m` for `super`, now also strips the `#pf` suffix, with
the copies cached by source pointer. The inlined-super lookup in
`emit_super_inline`, which used `s->name` raw, now goes through it too. The two
analysis sites that resolve `super` (`analyze_infer.c`, `analyze_scope.c`)
already call it, so they pick up the fix.

```
 src/codegen.c                       |  4 ++--
 src/compiler.c                      | 17 ++++++++++++++++-
 test/super_in_proc_form.rb          | 20 ++++++++++++++++++++
 test/super_in_proc_form.rb.expected |  8 ++++++++
 4 files changed, 46 insertions(+), 3 deletions(-)
```
The test covers bare and explicit-argument `super` from an anonymous-`&`
override, a three-level chain, and a yielding override whose `super` goes to a
plain parent, with and without a block. Every call goes through a poly receiver.

## Gates (`LANG=C.UTF-8 make -k -j4 gate TEST_JOBS=-j4`, one per branch)

| | bare (A) | splice (B) | pf-name (C) |
|---|---|---|---|
| Tests | 4011 pass, 2 fail, 0 error | 4011 pass, 2 fail, 0 error | 4010 pass, 2 fail, 0 error |
| Benchmarks | 62 pass (see below) | 62 pass | 62 pass |
| Optcarrot / infer-test / spin-e2e | OK / pass / ALL GREEN | same | same |
| rubyspec: language, core/array, core/string, core/hash, core/integer, core/range | all 671/421/571/192/171/83 still pass | same | same |

On every branch the 2 failures are the README's known sandbox ones.

**Benchmarks on A:** its gate reported `Benchmarks: 56 pass, 0 fail, 6 error`.
The six errors were the first six benchmarks alphabetically (`bm_ackermann` …
`bm_csv_process`), and the log shows `build/spinel-timeout` being compiled
three times by parallel gate legs at startup, so this looks like a race. Each
of the six passes on its own, and a rerun of the whole leg (`make bench`)
gave `Benchmarks: 62 pass, 0 fail, 0 error, 0 skip`. I committed A only after
that rerun.

## Surprising / notes

- **The gate's startup race is intermittent.** It can fail benchmarks that
  have nothing to do with the change. Worth knowing when a gate reports
  benchmark ERRs and nothing else.
- **Test variables matter.** A variable assigned objects of several classes is
  a poly value. My first coral-bunting variants reused `o` for every class, and
  that alone sent the calls through the `#pf` clone and bug C. The tests now
  use one variable per class.
- **About two hours of this brief was gate time.** Three root causes meant
  three sequential gates of 40–45 minutes each. Running them in parallel risks
  timeouts in this container.
- Worktrees: `../work6` (A), `../work7` (B), `../work8` (C).
