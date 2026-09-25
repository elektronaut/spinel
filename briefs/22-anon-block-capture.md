status: done
branch: fix-anon-block-capture-cells

# anon-block-capture (handle: ashen-plover). Silent wrong value.

An anonymous `&` forwarded into a method that stores the block, where the
block captures and writes an outer local, loses the writes (CRuby 7, Spinel 0).

Cause found by the brief-03 session: analyze.c (~14726) always marks a method
with an anonymous `&` as `yields` ("always safe to inline") and skips the
escape and forward checks named block params get. So the block is inlined and
its captures are copied by value. It can't simply be left un-inlined, because a
real function has no name for an anonymous block param (`blk_param == ""`); the
lowering pass (~15818) and the each materializer (~3422) skip it for the same
reason. Suggested direction: desugar an anonymous `&` to a synthetic named param
(as `__anon_kwrest` does for `**`), then let the named machinery decide. This
touches every special case for anonymous `&` (e.g. `fwd_drop_spent_anon_block_param`,
#4625). It's broad: gate carefully, and add variants (ivar receiver, `Reg.new(&)`,
two levels of forwarding).

Branches from briefs 02, 03 and 04 (`fix-forwarded-block-ivar-write`,
`fix-new-block-forwarding`, `fix-anon-block-forward-capture`) touch nearby code
and aren't merged. Base on upstream/master, but read their diffs first.

- `22-anon-block-capture/capture.rb`
