# Draft notes

One issue and one PR per fix branch: `issue-<branch>.md` and `pr-<branch>.md`. The first line is `title: ...`. Every issue's Spinel output was checked on upstream `86aa1cbf`, and every reproducer still fails there.

Placeholders: each PR opens with `Fixes #N.`, and a `#N` inside a body always has the other branch's name next to it in backticks. Numbers of filed PRs are already filled in: #4970, #4972, #4974, #4976.

## Decide before filing

- **pf-super and pf-name are the same bug.** `fix-block-forward-errors-pf-super` and `fix-super-anon-block-pf-name` both fix `super` inside an `m#pf` clone. Each one passes the other's tests. File only one. pf-name looks more complete, because it also routes `emit_super_inline` through the fix. Each PR has a paragraph about the overlap; delete it once you've picked.
- **named-anon may be redundant.** With `fix-anon-block-capture-cells` built on its own, the reproducer and test for `fix-block-forward-drops-named-anon` already pass. Merge #4974, `fix-forwarded-block-ivar-write-new` and `fix-anon-block-capture-cells` first, then check again.
- **Brief 09 string vs brief 28.** `fix-hash-through-getters-string` and `fix-string-mutation-through-reader` both fix `[]=` and `insert` through a reader, in the same files. The brief-28 issue no longer shows the `[]=` shape; it points to the brief-09 issue with `#N`. Whichever of the two lands second has to be rebased.
- **zero-arg-pf overlaps poly-zero-arg-arity.** `fix-build-breaks-zero-arg-pf` also adds the zero-argument ArgumentError arm, on the same `cls0_cand` line. Merge `fix-poly-zero-arg-arity` first, then rebase zero-arg-pf down to its `analyze.c` change. Its PR has a paragraph about this overlap.

## Text that changes after a rebase

- `fix-rest-default-binding`: the `**kwrest` half duplicates 00bac566 on master, so the commit subject, the PR title and one PR sentence may lose it. The `poly_arm_count` special case in `codegen_call.c` is then out of date.
- `fix-rest-default-binding-pd`: the poly arm's `**kw` binding `{}` is already on master (#4958), so drop that line from the PR.
- `fix-rest-default-binding-splat-tail`: the `opt_before_required(c, m)` signature change has to reach the three one-argument callers now on master, and the `emit_call_arity_check` call from #4970. So the diff will be bigger than the PR says.

## Merge order

- #4970 → #4972 → `fix-inline-yield-arity`
- #4976 → `fix-forwarded-block-ivar-write-new` (take #4974's `emit_class_new_call` hunk) → `fix-anon-block-capture-cells`
- `fix-block-forward-drops-new` after #4974. It also conflicts with `fix-class-value-new-arms-super` in `codegen_internal.h`.
- `fix-class-value-new-arms-struct` and `-selfnew` conflict on one line in the boxed-receiver class filter. The one that goes second keeps the selfnew shape and uses `if (!c->classes[ci].instantiated) continue;`.
- `fix-seeded-array-ivar-replace` and `-store` conflict only on the Makefile `rbs-seed-test` line; keep both.
- The two `fix-rest-default-binding` / `-splat-tail` branches: expect an adjacent-hunk conflict at the top of `arg_slot_for_param`; keep both.
