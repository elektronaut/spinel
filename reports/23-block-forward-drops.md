# 23-block-forward-drops: report

Two root causes, so two branches, each based on upstream/master `ab41b4ae`. All
three brief reproducers are fixed. The branches merge cleanly with each other.

## ruddy-tern: `fix-block-forward-drops-new` @ `4ec1a6a3`

**Root cause:** a constructor's `&blk` slot was filled separately by each spelling
of `new`, and most got it wrong:
- **Bare `new(&h)` in a class method:** left the slot out, so the C failed with "too
  few arguments to sp_Reg_new". The local-held-class, exception, leaf `self.class.new`
  and generic static paths had the same omission.
- **The Class-value dispatches** (zero-arg, positional, keyword/splat, boxed receiver)
  passed NULL through `emit_ctor_block_slot` whatever the call carried. That is the
  `self.new(&h)` case: it built the object with no block.
- **The positional and boxed-receiver dispatches** refused a call with arguments and a
  block.
- **A static `K.new(&h)` inside an inlined method** read the callee's `lv_h`,
  undeclared at the site (master too).

**Fix:**
- `emit_ctor_block_slot` takes the call node and resolves the block the way other
  block-passing calls do: a literal via `resolve_forwarded_block`, a proc value, an
  anonymous `&`, or a boxed proc. The existing refusal for a block of an unmodeled
  static type is kept.
- The Class-value dispatches hoist the proc once as a rooted temp, shared by their
  arms.
- `emit_ctor_alloc_init` takes the call too, because `sp_X_initialize` has the slot.
- The positional and boxed dispatches (and the analyzer's typing of boxed `new`)
  accept a block unless some class has a yielding initialize, which is only inlined at
  static sites.

**Tests:** `ctor_forward_block_self_new`, `ctor_forward_block_bare_new` (the two
reproducers), and `ctor_forward_block_arms` (inlined static `K.new(&h)`, a Class
value with and without arguments, a boxed receiver, an anonymous `&`, class-method
`new(n, &h)` and `self.new(3, &)`).

```
 src/analyze_infer_recv.c                     |  15 ++-
 src/codegen_call.c                           | 160 +++++++++++++++++----------
 src/codegen_internal.h                       |   2 +-
 test/ctor_forward_block_arms.rb              |  41 +++++++
 test/ctor_forward_block_arms.rb.expected     |  10 ++
 test/ctor_forward_block_bare_new.rb          |   8 ++
 test/ctor_forward_block_bare_new.rb.expected |   1 +
 test/ctor_forward_block_self_new.rb          |   8 ++
 test/ctor_forward_block_self_new.rb.expected |   1 +
 9 files changed, 185 insertions(+), 61 deletions(-)
```

**Gate** (LANG=C.UTF-8):
```
Tests: 4011 pass, 2 fail, 0 error      (tmpdir root, socket UDP: the known two)
Benchmarks: 62 pass, 0 fail, 0 error, 0 skip; infer-test: pass
rubyspec-gate: language 671, core/array 421, core/string 571, core/hash 192,
               core/integer 171, core/range 83 expected-PASS still pass
```

## slate-curlew: `fix-block-forward-drops-named-anon` @ `5205a0e8`

**Root cause:** `Outer#install(&blk)` is a real function. It splices the anonymous
forwarder `Front#install(&) = @k.install(&)` with `&blk`, a proc local. The
`emit_inline_call_x` BlockArgumentNode branch then runs the splice with no literal
block (`g_block_id = -1`) and records the proc as `g_yield_proc_ref`, which only
`yield` reads. The `&` forward inside went through `resolve_forwarded_block`, found
no literal, and `Keeper#install` got NULL. Named-into-named worked because a named
`&b` there is a real TY_PROC local.

**Fix:**
- `forwards_inline_proc` / `resolve_forwarded_block_or_proc` (codegen_fold.c): a
  forward (anonymous, or naming the inline's `g_block_param_name`) while the inline
  runs under a proc resolves to that proc, and `emit_forwarded_proc_arg` writes it.
- These are used at every site that passes a block on as a proc value:
  `emit_cmethod_block_arg`, `emit_method_call`, the two block-arg paths in
  codegen_fold, the poly-dispatch proc hoists (zero-arg and n-arg), and the
  class-method cascade. The last two also try `emit_forwarded_proc_arg` before
  `emit_proc_literal`.
- **Deliberately not changed:** `resolve_forwarded_block` itself, whose other callers
  are builtin-iterator splicers that need a literal body.

**Tests:** `block_forward_named_into_anon` (the reproducer) and
`block_forward_named_into_anon_arms` (named→named→anon, a poly receiver, a top-level
anonymous forwarder). The arms test fails on master.

```
 src/codegen_call.c                                 | 18 +++++----
 src/codegen_fold.c                                 | 32 ++++++++++++++--
 src/codegen_internal.h                             |  2 +
 test/block_forward_named_into_anon.rb              | 21 +++++++++++
 test/block_forward_named_into_anon.rb.expected     |  1 +
 test/block_forward_named_into_anon_arms.rb         | 43 ++++++++++++++++++++++
 .../block_forward_named_into_anon_arms.rb.expected |  4 ++
 7 files changed, 110 insertions(+), 11 deletions(-)
```

**Gate** (LANG=C.UTF-8):
```
Tests: 4010 pass, 2 fail, 0 error      (the known two)
Benchmarks: 61 pass, 0 fail, 1 error (bm_ao_render) -- see below
infer-test: pass
rubyspec-gate: language 671, core/array 421, core/string 571, core/hash 192,
               core/integer 171, core/range 83 expected-PASS still pass
```

`bm_ao_render` recorded ERR, meaning its `spinel -c` step failed or timed out
(TIMEOUT10) during the gate. I couldn't reproduce it on the same build: the compile
takes 0.04 seconds, the binary's output matches `.expected`, and `make bench` on its
own gives 62 pass, 0 fail, 0 error. The diff doesn't touch anything that program
compiles differently. I read it as load during the parallel gate, not a regression,
but a re-run in the triage session would settle it.

## Follow-ups / surprises

- **Combined-branch gap:** once both branches are merged, a constructor forward of an
  inline's proc (`def make(&) = Reg.new(&)` spliced into a `&blk` method) still goes
  through plain `resolve_forwarded_block` in `emit_ctor_block_value`. The one-line
  follow-up after merging is to switch it to `resolve_forwarded_block_or_proc`. I kept
  the branches separate as the README requires.
- **Other shapes of slate-curlew's bug:** the builtin-iterator splicers in codegen_fold
  (`xs.each(&)` inside such a splice) see the same "no literal, proc present" state.
  Driving the proc there is a separate change, and I didn't probe it.
