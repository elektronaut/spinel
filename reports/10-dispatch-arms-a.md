# dispatch-arms-a: report

**Status:** done. Both bugs are fixed, on one branch per root cause. Both
branches are based on upstream/master `032c037a`.

| Bug | Branch | Commit |
|---|---|---|
| yarrow-hare | `fix-dispatch-arm-gaps-inline-arm` | `73eb40a4ed520a097087a4313457b5a37deb1646` |
| auburn-gannet | `fix-dispatch-arm-gaps-yield-ctor` | `74aaa6bd0c00f98208ee6c0487691c3e8c59d7fd` |

The brief's branch name `fix-dispatch-arm-gaps` was only used locally and was
not pushed. The two branches merge without conflict: I checked this with a
three-way apply of B onto A. Both touch `make_yield_proc_forms`, but in
separate hunks.

The brief says to check `doc/internals.md` for a "known dispatch gap" note.
Neither `doc/` nor `docs/internals/` has one: there is no such file or
note on master.

## yarrow-hare: an inline-only override's arm was skipped

**Root cause.** A method whose block is used only by `.call`/`.nil?`, or that
yields, is marked `yields` and inlined at its call sites, so it has no C
function of its own. The `cls_id` dispatch switch (`codegen_fold.c`) keeps only
arms that have a symbol (`scope_has_callable_symbol`). It dropped `C#m`'s arm,
and `A#m` ran for a `C`. The poly-receiver dispatch solved this with proc-form
clones (#3399). But clones were made only for names called on a poly receiver
(`pf_wanted`), and the `cls_id` switch never used them.

**Fix.**
- `analyze.c`: a proc form is also made when a class above or below defines
  the same name, which means the method sits in a class dispatch. This skips
  `initialize`, class methods and Struct classes.
- `codegen_fold.c`: a new `dispatch_arm_scope` gives the arm the clone when the
  method has no symbol. Any clone arm forces the per-arm path, because a clone
  always takes the block. The arm unboxes the clone's poly return when the
  switch's slot is concrete, and the `default:` arm uses the base's clone too.
- **Sibling site** (`codegen_iter.c`, `emit_inline_call_x`): in the mirrored
  case the *base* method is the inline-only one. There the call was spliced
  from the base body even when a subclass overrides it (`G.new.run` printed 2
  instead of 7). The splice now declines when `dispatch_impl_count > 1` and a
  clone exists, so the call goes through the switch.

**Diff stat**
```
 src/analyze.c                                      | 21 ++++++-
 src/codegen_fold.c                                 | 39 ++++++++++---
 src/codegen_iter.c                                 |  9 +++
 test/dispatch_inline_only_override.rb              |  9 +++
 test/dispatch_inline_only_override.rb.expected     |  2 +
 test/dispatch_inline_only_override_variants.rb     | 65 ++++++++++++++++++++++
 ...patch_inline_only_override_variants.rb.expected | 13 +++++
 7 files changed, 149 insertions(+), 9 deletions(-)
```
The variants cover a block passed through the switch, a `yield`-based override,
an inline-only base with a plain override (with and without a literal block),
and three levels with the same `Integer` return on every arm (the unbox path).
Both tests fail on master.

**Gate** (`LANG=C.UTF-8 make -k -j4 gate TEST_JOBS=-j4`)
```
Tests: 3997 pass, 2 fail, 0 error
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
The two failures are the README's known sandbox ones: `pkg.tmpdir.tmpdir_expand_usable`
and `socket_ipv6_and_class_methods`.

## auburn-gannet: a Class value's `new` skipped a yielding initialize

**Root cause.** A yielding `initialize` (one that yields or forwards an
anonymous `&`) has no function either. A constant `X.new` site splices its body
(`emit_ctor_yield_inline`), and `sp_X_new` only allocates. Every switch arm of a
`new` whose class is known only at run time (`k.new`, a Class read from a
container) calls `sp_X_new`, so the object came back with no ivars set and no
error: `B(,)`. The splice's own fallback, when it declines, lands on the same
allocation-only `sp_X_new`; the code comment there says so.

**Fix.** When the program has a `new` with a non-constant receiver, a yielding
`initialize` gets its proc-form clone (`pf_wanted`). For a heap class with such
a clone (`ctor_init_proc_form`), the constructor is split in two:
- the allocation body is now `sp_X_new_noinit`
- `sp_X_new` allocates through it, then runs the clone with a NULL block,
  converting each parameter to the clone's type

The splicing site allocates through `sp_X_new_noinit`, so a static site runs the
body exactly once; the variants count that with a global. Changing
`sp_X_new` fixes all the dynamic-`new` arm emitters at once (about ten call
sites), without touching them. Struct and value-type classes are left
unchanged, because they have their own constructor emitters.

**Diff stat**
```
 src/analyze.c                                      | 23 +++++++++
 src/codegen.c                                      | 58 +++++++++++++++++++++-
 src/codegen_call.c                                 |  5 +-
 src/codegen_internal.h                             |  1 +
 test/class_value_new_yielding_init.rb              | 16 ++++++
 test/class_value_new_yielding_init.rb.expected     |  2 +
 test/class_value_new_yielding_init_variants.rb     | 52 +++++++++++++++++++
 ...ss_value_new_yielding_init_variants.rb.expected | 10 ++++
 8 files changed, 165 insertions(+), 2 deletions(-)
```
The variants cover:
- the anonymous-`&` forwarder
- an inherited yielding `initialize` (the parent cast)
- a zero-parameter `initialize`
- a zero-argument `Class`-variable `new`
- static sites with blocks, with a run counter

Both tests fail on master.

**Gate**: the same summary lines as above: `Tests: 3997 pass, 2 fail, 0 error`, with
the same two known failures. Benchmarks 62/62, Optcarrot OK, infer-test pass,
spin-e2e ALL GREEN, and all six rubyspec checks pass.

## Surprising / follow-ups

- **Struct classes are excluded from the new clone rule.** Every struct class
  gets its own copy of the generated `each`/`each_pair`/`each_with_index`, so a
  struct subclass always looks like an override. Cloning those bodies was
  refused ("proc referencing an uncaptured outer variable `__enum_acc`") in
  `struct_subclass` and `super_into_attr`: the clone doesn't carry the
  desugared accumulator local. A real override of a yielding method on a
  Struct subclass therefore still has the yarrow-hare gap. Fixing it needs the
  clone to carry desugared locals.
- **Value-type classes** with a yielding `initialize` still build
  allocation-only when constructed through a Class value. That constructor has
  its own emitter, and I left it alone.
- **Declining the splice changes how the call is compiled.** When the base
  method is inline-only and overridden, a call to it now goes through the switch
  and a real `sp_Proc`, where it used to be spliced inline. I checked this:
  - `next` in such a block works: `[3, 14]`, as in CRuby.
  - `break` does not. `def run = m(5) { |v| break v * 100 }` fails to compile
    on master even with no override ("void value not ignored as it ought to
    be"), so this is a separate bug that already existed. With the override
    present, branch A now compiles it, but it raises
    `break from proc-closure (LocalJumpError)` instead of answering 500. That
    is still wrong, though it's no longer a compile failure. It's worth a
    brief of its own.
- Worktrees used: `../work3` (A) and `../work4` (B).
- Brief 11 (`class-value-new`, claimed by another session) works in the same
  area, the class-value `new` arms in `codegen_call.c`. Branch B doesn't touch
  those arms. It changes `sp_X_new` itself and the splice site
  (`emit_ctor_yield_inline`), so the two shouldn't conflict textually. But once
  both land, a class-value `new` of a Struct or of a user `self.new` class with
  a yielding `initialize` would exercise both fixes together.
