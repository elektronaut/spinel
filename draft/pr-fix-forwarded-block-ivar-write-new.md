title: A forwarded block reaches a stored-block new and super from an inlined body

Fixes #N.

A method whose block is only forwarded is yield-inlined into its caller, and inside the splice the forward `&` or `&blk` stands for the caller's literal block (`g_block_id`). `resolve_forwarded_block` turns such a forward into that literal, and most call sites run it first. Two sites that hand a block to a parameter that stores it didn't. `emit_super_block_arg` in `src/codegen.c` read the `super` call's block node raw. An anonymous `&` has no expression, so it fell through to the "no block" case and passed `NULL`, and the parent's `@handler` was nil. A named `&blk` was emitted as `lv_blk`, the inlined method's own parameter, which the splice never declares, so the C didn't compile. A bare `super` or `super()` only passed the method's own block param when the method is a real function (`!s->yields`), and otherwise passed `NULL`. The stored-block arm of `emit_class_new_call` in `src/codegen_call.c` had the same raw read for `Klass.new(&)` / `Klass.new(&blk)` into an `initialize(&handler)`.

Both sites now call `resolve_forwarded_block` on the block node first, so a forward inside an inlined body materializes the spliced literal with `emit_proc_literal`. An implicit `super` in an inlined body (`s->yields` with `g_block_id >= 0`) passes the spliced block too. An anonymous `&` that survives resolution is inside a real function, and the `.new` arm now forwards that function's own block param with `emit_forwarded_proc_arg`, as its sibling call sites already do. Everything else stays the same: a literal block, a proc value, a poly-carried proc and the refusal for a block of an unmodeled type take the same paths, a node that doesn't resolve is kept as written, and with no block at the call the stored block is still nil, not a stale one.

The `Klass.new` half is the same fix as #4974 (`fix-new-block-forwarding`), and the two conflict in `emit_class_new_call`. If #4974 merges first, take its hunk there. The `super` half is only here.

This builds on #4976 (`fix-forwarded-block-ivar-write`), which must merge first. The test's blocks write ivars, and without that fix the proc materialized in the splice would capture the wrong `self`.

Tests: `test/forwarded_block_stored_new_super.rb` covers `Register.new(&)`, `Register.new(&blk)`, `super(&)`, `super(&blk)`, a bare `super` and `super()`, each forwarding a block that writes an ivar of the calling object, and the no-block case for `new(&)` and a bare `super` (still nil). It fails on master and matches CRuby 4.0 with this change. `make gate` is clean apart from the two known sandbox failures, `pkg.tmpdir.tmpdir_expand_usable` and `socket_ipv6_and_class_methods`.

Not covered: a poly receiver whose `on` forwards its block to `super` raises `super: no superclass method 'on#pf'`, because the poly dispatch arm has no `super`. That's a separate site and reproduces on master.
