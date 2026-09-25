title: replace on a seed-pinned typed array converts a source of another kind

Fixes #N.

The typed-array arms for `replace` in `src/codegen_call_recv.c` fire only when the source has the receiver's own kind (`a0 == rt`). That was enough without a seed: a `replace` with a boxed source or an array of another kind widens the receiver's slot to a general Array during inference, so a mismatched source never reaches a typed receiver. A true `--rbs` seed (`@storage: Array[Integer]`) stops the slot from widening. `@storage` stays an `sp_IntArray *` while `fill(initial)` is a boxed value, no arm matches, and the call falls through to the NoMethodError gate, which reports `replace` as undefined for an Array.

A new arm handles an Int, Float or Str array receiver whose source is boxed, a general Array, or another typed array kind. It roots the receiver, boxes the source, checks that the boxed value is an Array of some kind, converts it to the receiver's kind through the same `sp_poly_as_*_array` read-back a seeded store uses (via `emit_unbox_text`), and calls the kind's `sp_*Array_replace`, answering the receiver. A nil or non-Array source raises `TypeError` ("no implicit conversion of NilClass into Array"), as in Ruby. A same-kind source still takes the existing arm, and without a seed the receiver widens as before, so the new arm is only reached where the call used to fail.

Tests: `test/rbs-seed/seeded_array_replace_kind.rb` (seed in `test/rbs-seed/sig/seeded_array_replace_kind.rbs`) is the issue's reproducer, and covers `replace` in value and statement position, a source longer than the receiver, a source passed in as a method argument, and a nil source raising `TypeError`. It is added to the `rbs-seed-test` list in the `Makefile`, which compiles with `-Werror=incompatible-pointer-types`. It fails on master and matches CRuby 4.0 with this change. `make gate` is clean apart from the two known sandbox failures, `pkg.tmpdir.tmpdir_expand_usable` and `socket_ipv6_and_class_methods`.

Not covered: only Int, Float and Str array receivers convert. A seeded object array (`Array[Foo]`) receiving a source of another kind wasn't tried.

The `fix-seeded-array-ivar-store` PR (#N) adds its test to the same `rbs-seed-test` line of the `Makefile`, so whichever merges second has a one-line conflict there; keep both names.

This was found in the badline C64 emulator built with an RBS seed that pins its memory `@storage` to `Array[Integer]`; the reproducer is its memory class reduced.
