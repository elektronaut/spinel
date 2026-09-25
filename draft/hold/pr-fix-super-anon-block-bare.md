title: A bare super from an inline-only method hands its block to the parent

Fixes #N.

A method that takes an anonymous `&`, or that yields, is inline-only: it is spliced into each call site and never gets a proc for its block. When such a method calls `super` into a parent that takes `&handler` and is a real C function, `emit_super_block_arg` builds the parent's block argument. It handled only a caller with a named `&blk` that doesn't yield, passing `lv_<blk>`, and emitted `NULL` in every other case. So the parent's `@handler = handler` stored `nil`, and the later `@handler.call(v)` raised `NoMethodError`. This hit a bare `super`, `super(tag, &)` and an implicit `super(tag)` alike, and also a yielding override calling `super`.

`emit_super_block_arg` now has two more cases for an inline-only caller. If a literal block is being spliced into it (`g_block_id`), `super` passes that block as a proc via `emit_proc_literal`, the same thing `emit_method_call` does for a forwarded `inner(&)`. If the splice is driven by a proc instead (`on(:p, &pr)`, `g_yield_proc_ref`), it passes that proc. With neither, it still passes `NULL`, so a call without a block still gives the parent `nil`. A caller with a real `&blk` proc takes the same path as before, and supers into a yielding parent go through `emit_super_inline` and are not affected.

Tests: `test/super_anon_block_bare.rb` is the issue's reproducer. `test/super_anon_block_bare_variants.rb` covers bare `super`, `super(tag, &)`, `super(tag)` (implicit block passing), a yielding method calling `super`, a call with no block (the parent sees `nil`), and a `&proc` caller for both the explicit and the yielding override. Both fail on master and match CRuby 4.0 with this change. `make gate` is clean apart from the two known sandbox failures, `pkg.tmpdir.tmpdir_expand_usable` and `socket_ipv6_and_class_methods`.

Not covered: when the same override is called on a poly receiver it runs as its `m#pf` clone, and its `super` then fails with `no superclass method 'm#pf'`. That is a separate bug, fixed by #N (`fix-super-anon-block-pf-name`); such a program needs both changes.
