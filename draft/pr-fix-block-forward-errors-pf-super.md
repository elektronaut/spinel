title: A proc-form clone's super falls back to the ancestor's plain method

Fixes #N.

A yielding method (which includes one that takes an anonymous `&`) called with a block on a poly receiver is reached through a proc-form clone named `<m>#pf`, made by `make_yield_proc_forms`. `emit_super` in `src/codegen.c` and the `super` case of `infer_uncached` in `src/analyze_infer.c` took the name to look up in the parent chain from the scope name, passed through `comp_prep_user_name`, which only strips a prepend prefix. Inside the clone that name is `on#pf`. An ancestor that also yields has a clone of its own under that name, so that case worked, but `Base#on(&handler)` only stores its block and has no clone, hence `no superclass method 'on#pf'`.

A new `comp_super_name` (`src/compiler.c`) is used at both sites. It keeps `<m>#pf` when some ancestor has that clone, and otherwise answers the plain `<m>`, caching the stripped copy. The obvious fix, stripping `#pf` every time, broke the case where the ancestor also yields: that ancestor's plain method is only ever inlined and has no C symbol, so the call didn't link. Names without the suffix, including prepend shadows, resolve exactly as before, and the plain method it falls back to is callable because only a yielding method is inlined away.

Tests: `test/poly_proc_form_super.rb` covers the issue's reproducer, `super(tag, &)` with changed arguments, and a yielding ancestor whose own clone the `super` must still reach (`def each_twice(&) = super(&)` and a bare `super`). It fails on master and matches CRuby 4.0 with this change. `make gate` is clean apart from the two known sandbox failures, `pkg.tmpdir.tmpdir_expand_usable` and `socket_ipv6_and_class_methods`.
