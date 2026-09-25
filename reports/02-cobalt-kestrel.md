# cobalt-kestrel: report

**Status:** done (two branches, second stacked on the first)

| Branch | Commit | Based on |
|---|---|---|
| `fix-forwarded-block-ivar-write` | `af572a7a` "A block forwarded out of an inlined method keeps its own self" | upstream/master `032c037a` |
| `fix-forwarded-block-ivar-write-new` | `abb73447` "A forwarded block reaches a stored-block new and super from an inlined body" | `af572a7a` (stacked) |

## Root cause 1: the brief's bug (`fix-forwarded-block-ivar-write`)

`Bus#install(&) = @register.handle(&)` is inlined into `Recorder#initialize`.
Inside the splice, the forwarded `&` resolves to the caller's literal block,
and `emit_proc_literal` turns it into a proc. It captured the current `g_self`
as the proc's self. Inside the splice that is the inlined callee's receiver
(`_capv_1->__self = (void *)_t5`, the Bus). The proc body casts `__self` to
`sp_Recorder *`, so `@code = value` wrote into the Bus's memory at Recorder's
field offset. The Recorder kept 0, and the variants file segfaulted on master.

Fix: `emit_proc_literal` is now a thin wrapper. When the block it materializes
is the spliced one (`create == g_block_id`, with the yield fallbacks set), it
emits the proc under `g_yield_self_fallback`, its deref, its emitting class,
and the block's own rename depth (`g_block_nren`). That is the same context
`emit_block_invoke` already restores when it splices that block for a
`yield`. One fix covers every site that materializes the spliced block:
anonymous `&`, named `&blk`, `Proc.new(&blk)`, two levels of forwarding, and
implicit-self calls in the block.

```
 src/codegen.c                                      | 25 +++++++
 test/forwarded_block_ivar_write.rb                 | 40 +++++++++++
 test/forwarded_block_ivar_write.rb.expected        |  1 +
 test/forwarded_block_ivar_write_variants.rb        | 80 ++++++++++++++++++++++
 ...forwarded_block_ivar_write_variants.rb.expected |  5 ++
 5 files changed, 151 insertions(+)
```

Gate (`make -k -j4 gate TEST_JOBS=-j4`, `LANG=C.UTF-8`):

```
Tests: 3997 pass, 2 fail, 0 error
Benchmarks: 62 pass, 0 fail, 0 error, 0 skip   (rerun; see below)
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

The two test failures are the known environment ones
(`pkg.tmpdir.tmpdir_expand_usable`, `socket_ipv6_and_class_methods`). In the
full gate run, `bm_ackermann` came out as `ERR`. That was a compile timeout:
the bench leg compiles each benchmark under a 10 s timeout, and I was building
a second worktree at the same time. `bm_ackermann` compiles in a few
milliseconds on its own. `make bench` rerun alone: 62 pass, 0 error.

## Root cause 2: sibling sites (`fix-forwarded-block-ivar-write-new`)

A sibling pattern turned up while probing variants. Two call sites that pass a
block into a *stored* block parameter read the call's `block` node raw and
never ran `resolve_forwarded_block`:

- `Klass.new(&)` / `Klass.new(&blk)` into an `initialize(&handler)`
  (`codegen_call.c`, the stored-block initialize arm).
- `super(&)`, `super(&blk)`, zsuper `super` and `super()` into a parent whose
  method stores `&handler` (`emit_super_block_arg` in `codegen.c`).

Inside an inlined body, the anonymous form looked like "no block" and silently
threaded `NULL`. The stored block was nil, and `.call` raised NoMethodError.
The named form emitted the callee's `lv_blk`, which the splice never declares,
so the C failed to compile. Zsuper and `super()` in an inlined body passed
`NULL` because of the `!s->yields` gate. All four fail the same way on
master. Both sites now resolve the forwarded block first. An implicit `super`
inside an inlined body passes the spliced block. An anonymous `&` that
survives resolution (a real function) forwards that function's own block
param, as `emit_forwarded_proc_arg` does for its siblings.

The branch is stacked on root cause 1 because its test blocks write ivars.
Without the self fix, those blocks would now receive a proc that captures the
wrong self.

```
 src/codegen.c                                     |  9 ++-
 src/codegen_call.c                                | 12 +++-
 test/forwarded_block_stored_new_super.rb          | 83 +++++++++++++++++++++++
 test/forwarded_block_stored_new_super.rb.expected |  8 +++
 4 files changed, 110 insertions(+), 2 deletions(-)
```

The test covers `new(&)`, `new(&blk)`, `super(&)`, `super(&blk)`, zsuper,
`super()`, and the no-block case (still nil, not stale). It matches CRuby.
On master it fails at `bus.register.poke(1)` (nil handler), and the named
forms fail to compile.

Gate:

```
Tests: 3998 pass, 2 fail, 0 error
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

## Merging (added after brief 22)

- **Overlap with brief 03.** `fix-forwarded-block-ivar-write-new` and brief
  03's `fix-new-block-forwarding` made nearly the same `Klass.new(&)` fix, and
  they conflict in `emit_class_new_call` when merged together. Take brief 03's
  hunk. The `super` half of `-new` (`emit_super_block_arg`: `super(&)`,
  `super(&blk)`, zsuper and `super()` from an inlined body) isn't in brief 03,
  so keep it.
- **Merge order.** `-new` is stacked on `fix-forwarded-block-ivar-write`, so
  merge that first.
- **Brief 22 depends on this.** Brief 22's `fix-anon-block-capture-cells`
  relies on the `.new` fix (from 03 or here) and on this branch's `super`
  fix. Without them, an anonymous `Reg.new(&)` or `super(&)` fails to compile
  instead of silently dropping the block.
- **Combined stack tested.** 22 + 03 + 04 + both branches here, with the
  conflict resolved toward 03, built in a scratch worktree. All seven related
  tests pass on it (see brief 22's report). I didn't gate the combination.

## Found, not fixed (pre-existing on master, separate root causes)

1. **A class method's `new(&h)` drops the block.**
   `def self.make(&h) = new(&h)` into `initialize(&h)` fails to compile
   (`too few arguments to function 'sp_Reg_new'`). The explicit
   `self.new(&h)` compiles but passes no block (`undefined method 'call' for
   nil`). This reproduces without any inlining, so it's a separate site.
   Reproducer:
   ```ruby
   class Reg
     def initialize(&h) = @h = h
     def self.make(&h) = self.new(&h)   # or new(&h): C compile error
     def poke(v) = @h.call(v)
   end
   p Reg.make { |v| v * 2 }.poke(21)    # CRuby: 42
   ```
2. **A poly receiver's `#pf` arm has no `super`.** When the method it calls
   forwards its block to `super`, the program raises NoMethodError:
   ```ruby
   class Base
     def on(&handler) = @handler = handler
     def fire(value) = @handler.call(value)
   end
   class A < Base; def on(&) = super(&); end
   class B < Base; def on(&) = super(&); end
   [A, B].each { |k| o = k.new; o.on { |v| p [k.name, v] }; o.fire(1) }
   # CRuby: ["A", 1] ["B", 1]
   # Spinel: super: no superclass method 'on#pf' for an instance of A (NoMethodError)
   ```
3. **Refused, not miscompiled.** A forwarded block that captures an outer
   *local* (`total = 100; bus.install { |v| @log << v + total }`) is refused
   with "proc referencing an uncaptured outer variable" (a loud refusal, same
   on master). Blocks that only touch ivars, globals or their own params work.

## Surprising

- On master, the brief's reproducer prints `0` only by luck. The proc writes
  a boxed value at Recorder's `iv_code` offset inside a `sp_Bus`. With more
  ivars or more calls (the variants file) it segfaults.
- The benchmark leg's 10 s compile timeout makes `bench` flaky under parallel
  load. Don't run another build while the gate runs.
- The full gate takes about 48 minutes in this container with nothing else
  running, not the ~10 the README suggests.
