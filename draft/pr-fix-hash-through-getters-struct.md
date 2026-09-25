title: An empty hash given to a Struct member is built as the member's variant

Fixes #N.

`struct_new_types_members` types each Struct member from the arguments of the `S.new(...)` calls, unifying the member's ivar type with each argument's type. Writes through the member's reader (`s.h[1] = 2`, `s.h["x"] = "y"`) are evidence for that member and widen it to `PolyPoly`. The empty `{}` argument, though, has no keys of its own, so its `hash_want` stayed at the empty literal's default, `StrPoly`. The constructor call then initialized a `sp_PolyPolyHash *` member from a `sp_StrPolyHash *` literal, and the C build refused it.

When a member's argument is an empty `HashNode` and the member's settled type is a hash, `struct_new_types_members` now sets that literal's `hash_want` to the member's type and reports a change, so the fixpoint rebuilds the literal as the member's variant. Only empty literals are retargeted: a literal with elements already contributes its own key and value types to the member through the existing unify, and changing its variant is left to that path. Non-hash members and non-literal arguments are untouched.

Tests: `test/struct_member_hash_mixed_keys.rb` is the issue's reproducer, plus a second instance of the same Struct with Integer keys only (read back with arithmetic), and a `keyword_init: true` Struct whose `tbl: {}` member takes a Symbol and a String key. It fails on master and matches CRuby 4.0 with this change. `make gate` is clean apart from the two known sandbox failures, `pkg.tmpdir.tmpdir_expand_usable` and `socket_ipv6_and_class_methods`.
