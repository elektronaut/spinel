# 11-class-value-new: report

Three root causes, so three branches, each based on upstream/master `032c037a`
with its own tests. All three brief reproducers are fixed. f5b needs **both B and
C**: its dynamic `build(1, 7)` reaches `C.self.new` (B), whose `super` is
Class#new (C). I checked B+C applied together: f5 and f5b both match the
`.expected` files.

## A. sleety-gadwall: `fix-class-value-new-arms-struct` @ `58a434c9`

**Root cause:** two sites in `codegen_call.c`:
- The positional `k.new(args)` emitter on a Class value did `if (initm >= 0) continue;`
  for a Struct with its own initialize. The comment claimed "the test above rules",
  but the line dropped the arm.
- The boxed-receiver emitter (`REG.fetch(0).new(...)`) skipped `is_struct` classes
  outright.

Both calls raised NoMethodError, while the splat form (`emit_class_value_new_kw`)
built the Struct.

**Fix:**
- A Struct with its own initialize constructs through it, like any class. A
  yielding one still has no arm.
- A generated constructor gets its members.
- A plain Struct (not Data or keyword_init) nil-fills missing members and refuses
  extra ones with "struct size differs". This matches the static `S.new`. The old
  exact-count test turned both cases into NoMethodError.

**Tests:** `class_value_new_struct_custom_init` (the reproducer) and `poly_new_struct_arm`.

```
 src/codegen_call.c                                 | 56 +++++++++++++++++++---
 test/class_value_new_struct_custom_init.rb         | 18 +++++++
 .../class_value_new_struct_custom_init.rb.expected |  3 ++
 test/poly_new_struct_arm.rb                        | 32 +++++++++++++
 test/poly_new_struct_arm.rb.expected               |  8 ++++
 5 files changed, 110 insertions(+), 7 deletions(-)
```

## B. wan-merganser (f5): `fix-class-value-new-arms-selfnew` @ `6efdd771`

**Root cause:** the generic class-method dispatch on a dynamic Class value (#2445)
claimed `new` whenever any class defined `self.new`. It had no arm for classes
that construct normally, and it typed the result from the user methods alone, so
a String-returning one failed in C. Without a user `self.new` in play, the `new`
emitters never consulted one either.

**Fix:**
- That dispatch now leaves `new` (typed poly) to the `new` emitters.
- A new `emit_user_new_arm` gives a class with its own `self.new` an arm calling
  it, in all four `new` emitters: positional, zero-arg, keyword/splat, and boxed
  receiver.
- The arm checks arity (ArgumentError) and packs a `*rest`. It binds keywords by
  name from the hoisted hash, because a sole keyword hash reaches the positional
  emitters. It passes the receiving class when the body reads it (#4217).

**Gate note:** the first gate run of B caught a regression. `class_value_new_splat`
reaches a `self.new(*a)` through a literal-splat call, and my first version
refused a rest parameter on the hoisted path. Rest packing fixed it. The final gate
is clean.

**Tests:** `class_value_new_user_selfnew` (f5) and `class_value_new_user_selfnew_arms`
(zero-arg, splat, keywords, rest+post, kwrest, a boxed receiver, an inherited
`self.new` reading `name`, arity).

```
 src/codegen_call.c                                 | 149 ++++++++++++++++++++-
 test/class_value_new_user_selfnew.rb               |  16 +++
 test/class_value_new_user_selfnew.rb.expected      |   3 +
 test/class_value_new_user_selfnew_arms.rb          |  47 +++++++
 test/class_value_new_user_selfnew_arms.rb.expected |  14 ++
 5 files changed, 227 insertions(+), 2 deletions(-)
```

## C. wan-merganser (f5b): `fix-class-value-new-arms-super` @ `0ad820af`

**Root cause:** `super` inside `def self.new` resolved only through the parent's
class-method chain. With no class method `new` above, it raised "super: no
superclass method 'new'" even for a static `C.new(7)`, and `puts C.new(7)` was
refused at compile time because the result was untyped. In Ruby it is Class#new.

**Fix:**
- New `comp_super_is_class_new` (compiler.c), used by:
  - the analyzer: typing, `initialize` parameter binding, the instantiation census;
  - `cmethod_takes_self_cls`;
  - a new `emit_super_class_new`, which allocates the receiving class and runs its
    initialize.
- With a descendant, the method takes the receiving class, one arm per class, and
  the result is boxed.
- Bare `super` forwards the parameters.
- **Sibling fix:** both static `K.new` sites that call a user `self.new` passed no
  receiving class. An inherited `self.new` reading `name` failed in C on master
  (reproduced). Both sites now use `emit_cmethod_self_cls_arg`.
- **Refused as unsupported (deferred):** `super` in `self.new` of a
  Struct/Data/exception/native class, and a bare `super` from a `self.new` with
  keyword/rest parameters.

**Test:** `super_in_selfnew_is_class_new`. f5b itself is not in C's tests, because it
needs B as well.

```
 src/analyze.c                                  |  10 +++
 src/analyze_infer.c                            |   7 ++
 src/analyze_pass.c                             |  19 +++++
 src/codegen.c                                  |   3 +
 src/codegen_call.c                             | 103 +++++++++++++++++++++++--
 src/codegen_internal.h                         |   1 +
 src/compiler.c                                 |  16 ++++
 src/compiler.h                                 |   1 +
 test/super_in_selfnew_is_class_new.rb          |  37 +++++++++
 test/super_in_selfnew_is_class_new.rb.expected |   7 ++
 10 files changed, 198 insertions(+), 6 deletions(-)
```

## Gates (LANG=C.UTF-8, each branch separately)

```
A: Tests: 3997 pass, 2 fail, 0 error
B: Tests: 3997 pass, 2 fail, 0 error
C: Tests: 3996 pass, 2 fail, 0 error
all three: Benchmarks: 62 pass, 0 fail, 0 error, 0 skip; infer-test: pass
all three: rubyspec-gate[language] 671, [core/array] 421, [core/string] 571,
           [core/hash] 192, [core/integer] 171, [core/range] 83 expected-PASS still pass
```

The only failures are the two known ones: `pkg.tmpdir.tmpdir_expand_usable` (root)
and `socket_ipv6_and_class_methods` (no UDP). There were no rubyspec extraction errors.

## Merging

B+C and A+C merge cleanly. **A+B conflict** on one line in the boxed-receiver
`new` emitter's class filter: A removed `c->classes[ci].is_struct ||`, and B split
the line to call `emit_user_new_arm` before the `instantiated` check.

To resolve, keep B's shape without `is_struct` in the second test:
`if (!c->classes[ci].instantiated) continue;`, placed after the `gen_ctor` setup, as A
expects.

## Found, not fixed

- **`to_s` skipped (separate bug):** a class that exists only as a Class value (e.g.
  `def pick(i) = [A, B][i]; puts pick(0).new(5)`) prints `#<A:0x…>` instead of
  calling its own `to_s` (master too). A static `A.new` anywhere in the program
  makes it work. `compute_instantiated` already marks every class for a dynamic
  `new`, so the cause is elsewhere, probably in how `puts` chooses its `to_s` arms.
  B's test works around it with one static `A.new`.
- **Commit author on brief 08:** `fix-poly-arm-arity` (08) was committed as `Claude
  <noreply@anthropic.com>`, before the README said to set the author. Amending it
  needs a force-push, which this session's permissions refused. The user has been
  told.
- **Brief 08 gate:** 08's gate ran with an empty LANG. A re-run with
  `LANG=C.UTF-8` was also refused in that session, so its rubyspec numbers should
  be re-checked.
