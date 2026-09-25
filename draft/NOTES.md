# Draft notes

Each fix branch has `issue-<branch>.md` and `pr-<branch>.md`. The first line of each file is `title: ...`, followed by a blank line, then the body. Every branch is one commit on upstream master `bcfc3470`, authored by Inge Jørgensen, and is pushed to elektronaut/spinel. Every issue's reproducer still fails on current master.

**Placeholders.** Each PR opens with `Fixes #N.`: put the new issue's number there. Any other `#N` in a body has another branch's name next to it in backticks; replace it with that branch's PR number once it's filed, or drop the sentence if that branch isn't filed yet. Real numbers (#4969–#4988) are already filled in.

**Gate wording.** Every PR says the gate was clean apart from two known sandbox failures, `pkg.tmpdir.tmpdir_expand_usable` and `socket_ipv6_and_class_methods`. The gate ran on each branch's old base. After the rebase, only each branch's new tests were run, and all pass. Five PRs say this explicitly because their rebase needed a conflict resolved.

## Batch 2: 23 branches, no conflicts with each other or with master

fix-array-new-block-string-local, fix-block-forward-drops-new, fix-block-forward-errors-ivar-cell, fix-block-forward-errors-pf-super, fix-build-breaks-write-arg, fix-class-value-new-arms-struct, fix-dispatch-arm-gaps-inline-arm, fix-dispatch-arm-gaps-yield-ctor, fix-forwarded-block-ivar-write-new, fix-hash-through-getters-alias, fix-hash-through-getters-misfit, fix-hash-through-getters-string, fix-hash-through-getters-struct, fix-hash-through-getters-super, fix-inline-yield-arity, fix-poly-array-op-assign, fix-poly-array-op-assign-recv-order, fix-poly-zero-arg-arity, fix-rest-default-binding, fix-rest-default-binding-pd, fix-rest-default-binding-splat-nil, fix-seeded-array-ivar-store, fix-silent-wrong-values-puts-to-s

## Held until batch 2 merges (each needs a rebase first)

| Branch | Waits for | Why |
|---|---|---|
| fix-anon-block-capture-cells | fix-forwarded-block-ivar-write-new | Without that fix, `super(&)` stops compiling. |
| fix-block-forward-drops-named-anon | fix-anon-block-capture-cells | Its tests already pass with 22 alone, so it may not be needed. |
| fix-class-value-new-arms-super | fix-block-forward-drops-new, fix-block-forward-errors-pf-super | Conflicts in `codegen_internal.h`, `analyze_infer.c` and `compiler.h`. |
| fix-class-value-new-arms-selfnew | fix-class-value-new-arms-struct | They conflict on one line of the class filter. Keep the selfnew shape and use `if (!c->classes[ci].instantiated) continue;`. |
| fix-build-breaks-zero-arg-pf | fix-poly-zero-arg-arity | Rebase it down to just its `analyze.c` change. |
| fix-string-mutation-through-reader | fix-hash-through-getters-string | Both fix `[]=`/`insert` through a reader in the same code. |
| fix-rest-default-binding-splat-tail | fix-rest-default-binding, -pd | Conflicts in `arg_slot_for_param` and the poly arm; keep both sides. |
| fix-seeded-array-ivar-replace | fix-seeded-array-ivar-store | They conflict only on the Makefile `rbs-seed-test` line; keep both. |

## On hold: brief 26 (`hold/`)

fix-super-anon-block-bare, -splice and -pf-name each pass their tests on master alone, and they haven't been rebased since. They break when combined with other fixes:
- With fix-anon-block-capture-cells, `super_anon_block_bare_variants` doesn't compile (`lv___anon_block`).
- fix-forwarded-block-ivar-write-new conflicts with -bare in `emit_super_block_arg`.
- In the 26-branch stack, `splice_variants` and `super_in_proc_form` fail. The cause isn't found yet; it isn't 22 or pf-super on their own.

pf-name fixes the same bug as pf-super, which is in batch 2.
