# 24-block-forward-errors

The brief's two root causes are on two branches, both from upstream/master
`ab41b4ae`.

## dun-grebe: `fix-block-forward-errors-pf-super`

- Commit `f58c3ffffbb97c4dbbf8c9914f757a91061b76bd`
  "A proc-form clone's super falls back to the ancestor's plain method"
- Diff stat:

```
 src/analyze_infer.c                   |  2 +-
 src/codegen.c                         |  2 +-
 src/compiler.c                        | 25 ++++++++++++++++++++++++
 src/compiler.h                        |  1 +
 test/poly_proc_form_super.rb          | 36 +++++++++++++++++++++++++++++++++++
 test/poly_proc_form_super.rb.expected |  8 ++++++++
 6 files changed, 72 insertions(+), 2 deletions(-)
```

**Root cause.** A yielding method called on a poly receiver gets a proc-form
clone named `<m>#pf` (`make_yield_proc_forms`). `super` inside the clone
resolved its name from the scope name, so it looked up `on#pf` in the parent
chain. An ancestor that yields has its own clone, but `Base#on(&handler)`
only stores its block and has none, hence "no superclass method 'on#pf'".

**Fix.** A new `comp_super_name` is used in codegen and in inference. It
keeps `<m>#pf` when an ancestor has that clone, and otherwise uses the plain
`<m>`. The obvious fix, stripping `#pf` every time, broke the case where the
ancestor also yields: its plain method is inlined away and has no C symbol,
so the link failed. The test covers both cases, plus `super(args, &)`.

## pearl-avocet: `fix-block-forward-errors-ivar-cell`

- Commit `f0020007b66dd60e7ede8eff058d6c9e922c1eb4`
  "A block to a block-keeping method on an untyped receiver is lifted early"
- Diff stat:

```
 src/analyze.c                              | 75 +++++++++++++++++++++++-------
 test/block_lifted_untyped_recv.rb          | 45 ++++++++++++++++++
 test/block_lifted_untyped_recv.rb.expected |  4 ++
 3 files changed, 106 insertions(+), 18 deletions(-)
```

**Root cause.** The yield-inlining pass decides whether `install(&handler)`
can be spliced. It asks `a_proc_create_or_lifted` which blocks are
proc-like, and `a_block_is_lifted` resolves the callee through
`infer_type(recv)`. At that point `@reg` has no type yet. The same is true of
a plain local assigned from `Reg.new`, so this isn't only an ivar problem.
The block therefore counted as spliced and `install` was inlined with no
storage for `handler`. Codegen, on settled types, then lifted the block and
referenced `_cell_handler`.

**Fix.** The `&blk`-forward analysis a few lines above already handles an
unresolved receiver by name: "take the one that KEEPS the block". I factored
that into `a_name_keeps_block` and added `a_block_lifted_by_callee_name`: a
literal block on a call whose receiver is still TY_UNKNOWN (not a constant)
counts as lifted when some method of that name keeps its block. It is used
only in the inline-candidacy scan. At worst it keeps a method out of line.

The test has three cases:
- the brief's ivar receiver;
- a local receiver;
- an ivar receiver whose callee only yields, which must still splice and run
  the handler.

## Gate (each branch, LANG=C.UTF-8)

Results on both branches:

```
Tests: 4009 pass, 2 fail, 0 error
FAIL: pkg.tmpdir.tmpdir_expand_usable   (known: root)
FAIL: socket_ipv6_and_class_methods     (known: no UDP)
Benchmarks: 62 pass, 0 fail, 0 error, 0 skip
Optcarrot: OK
infer-test: pass
rbs-seed-test: pass
spin-e2e: ALL GREEN
rubyspec-gate[language]: all 671 expected-PASS examples still pass
rubyspec-gate[core/array]: all 421 expected-PASS examples still pass
rubyspec-gate[core/string]: all 571 expected-PASS examples still pass
rubyspec-gate[core/hash]: all 192 expected-PASS examples still pass
rubyspec-gate[core/integer]: all 171 expected-PASS examples still pass
rubyspec-gate[core/range]: all 83 expected-PASS examples still pass
```

On the pf-super branch, the first full gate showed "Benchmarks: 59 pass,
3 error". The errors were the first three alphabetically (bm_ackermann,
bm_ao_render, bm_attr_accessor), because I was building the other worktree
while it started. All three pass when run by hand, and a rerun of
`make gate-bench` on that branch gave 62 pass, 0 error.

## Surprising / not fixed (both pre-existing on master)

1. **Poly dispatch drops the block for `super(&)` into a yielding ancestor.**

   ```ruby
   class PfBase; def each_twice; yield 1; yield 2; end; end
   class PfA < PfBase; def each_twice(&) = super(&); end
   class PfB < PfBase; def each_twice(&) = super; end
   [PfA, PfB].each do |k|
     o = k.new
     o.each_twice { |x| p x * 10 }
   end
   ```

   Ruby prints 10, 20, 10, 20. Spinel, on master and on these branches,
   prints only PfB's pair. The dispatch arm for PfA inlines `super(&)` with
   the yields as `(void)(1LL)`, so the anonymous `&` never reaches the
   spliced block. Calling `k.new.each_twice { }` directly takes the `#pf`
   clone and works.

2. **Bare `super` from `def on(tag, &)` drops the block (monomorphic).**

   ```ruby
   class Base
     def on(tag, &handler) = @handler = handler
     def fire(v) = @handler.call(v)
   end
   class A < Base
     def on(tag, &) = super
   end
   a = A.new
   a.on(:x) { |v| p v }
   a.fire(3)
   ```

   Ruby prints 3. Spinel on master raises "undefined method 'call' for nil".
   A bare `super` doesn't forward an anonymous `&` block to a parent that
   keeps it as `&handler`.
