# gilded-teal (+ pewter-crake): report

**Status:** done (all five reproducers fixed; two related pre-existing bugs found and left, see below)
**Branch:** `fix-new-block-forwarding` (on origin, based on upstream/master `032c037a`)
**Commit:** `ed6bbe276f59d72938e4f5b3fbb332e6034b0372` — "A block handed to Klass.new reaches a storing initialize"

gilded-teal and pewter-crake have one root, with two halves, so they share one branch.

## Root cause

A method whose `&blk`/`&` is only forwarded is yield-inlined at its call sites.
1. **Codegen** (`emit_class_new_call`, the stored-block initialize arm in
   `codegen_call.c`): the call's `BlockArgumentNode` was used as-is. A named
   `&blk` was emitted as `lv_blk`, which no inline site declares (b.rb, r14). An
   anonymous `&` has no expression, so it fell to `NULL` (f.rb, r13).
   `emit_method_call` already runs the block through `resolve_forwarded_block` +
   `emit_forwarded_proc_arg`, and this arm now does the same.
2. **Analyzer** (`analyze.c`): both the forward-callee resolution in the
   inline-candidate pass and `a_block_is_lifted` looked `Klass.new` up as a
   *class method* `new`. Without a `def self.new` that lookup finds nothing, so
   forwarding into a storing initialize (or passing it a literal block) never
   counted as an escape. The forwarder stayed inlined and captures got no cells:
   b.rb's `box` and r16's `handler` were then refused as "uncaptured outer
   variable". Both lookups now fall back to `initialize` when there is no
   `def self.new` (the same mapping analyze.c already uses at ~7213 and ~13777).

## Diff stat

```
 src/analyze.c                         | 11 ++++-
 src/codegen_call.c                    |  8 +++-
 test/new_block_forwarding.rb          | 78 +++++++++++++++++++++++++++++++++++
 test/new_block_forwarding.rb.expected |  5 +++
 4 files changed, 100 insertions(+), 2 deletions(-)
```

The test covers: anonymous `&` at top level and in an instance method, named
`&blk` with a positional arg and a captured caller local, a literal block to
`new` reading the outer block param, and two install sites sharing a captured
counter. The expected file is from `ruby`, and all brief reproducers print 7.

## Gate (`make -k -j4 gate TEST_JOBS=-j4`, LANG=C.UTF-8)

```
Tests: 3996 pass, 2 fail, 0 error
  FAIL: pkg.tmpdir.tmpdir_expand_usable      (known: root in container)
  FAIL: socket_ipv6_and_class_methods        (known: no UDP in sandbox)
Benchmarks: 62 pass, 0 fail, 0 error, 0 skip
Optcarrot: OK
infer-test: pass
spin-e2e: ALL GREEN   (with the known "push negotiation failed" warning)
rubyspec-gate[language]: all 671 expected-PASS examples still pass
rubyspec-gate[core/array]: all 421 expected-PASS examples still pass
rubyspec-gate[core/string]: all 571 expected-PASS examples still pass
rubyspec-gate[core/hash]: all 192 expected-PASS examples still pass
rubyspec-gate[core/integer]: all 171 expected-PASS examples still pass
rubyspec-gate[core/range]: all 83 expected-PASS examples still pass
```

## Not fixed: two related bugs, both also failing on master

1. **Anonymous `&` into a *storing* callee, with a capturing block: silent wrong
   result.**
   ```ruby
   class Reg; def set(&h) = @h = h; def poke(v) = @h.call(v); end
   R = Reg.new
   def install(&) = R.set(&)          # same with `Reg.new(&)`
   total = 0
   install { |v| total += v }
   R.poke(3); R.poke(4)
   p total                            # CRuby 7, spinel 0
   ```
   The `Reg.new(&)` spelling printed `undefined method 'call' for nil` before this
   branch and prints `0` after. Cause: analyze.c ~14726 always marks an anonymous
   `&` method `yields` ("always safe to inline") and skips the escape and forward
   checks that named params get. So the block is inlined and its captures are
   copied by value. It can't simply be left un-inlined, because a real function
   has no name for an anonymous block param (`blk_param == ""`). The lowering pass
   at ~15818 and the each materializer at ~3422 skip it for the same reason.
   Likely fix: desugar an anonymous `&` to a synthetic named param (as
   `__anon_kwrest` does for `**`), then let the named machinery decide. That
   touches every special case for anonymous `&` (e.g. `fwd_drop_spent_anon_block_param`,
   #4625), so it's too broad for this brief.

2. **Literal block reading the outer block param, passed to a method on an
   *ivar* receiver: C compile error.**
   ```ruby
   class Reg; def set(&h) = @h = h; def poke(v) = @h.call(v); end
   class Bus
     def install(&handler)
       @reg = Reg.new
       @reg.set { |v| handler.call(v) }
     end
     def poke(v) = @reg.poke(v)
   end
   b = Bus.new; b.install { |v| puts v }; b.poke(7)   # CRuby 7
   ```
   The error is `'_cell_handler' undeclared`. This is the `@reg.set` sibling of
   r16. `a_block_is_lifted` resolves the target via `infer_type(recv)`, and while
   the inline-candidate pass runs, `@reg` is not yet typed. So the block isn't
   seen as lifted, `install` is inlined, and codegen later lifts the block and
   references a cell that analysis never created. The constant-receiver spelling
   (r16, `Klass.new {}`) is fixed by this branch because it doesn't need the type.
