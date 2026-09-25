status: claimed
branch: fix-surplus-arg-refusal
deadline: 11:20 Oslo (matz merges at 11:28; after 11:20, skip)
pr: 4970

# Review fixes for PR #4970

Fetch the branch first: its tip was amended this morning to add `Fixes #N`.
Fix each finding you can verify, before the deadline, as a new commit on top.
Never force-push. The report lists each finding (by comment id) as fixed,
not valid or skipped, and gives a 1–3 sentence reply for each fixed or
not-valid finding, which the triage session posts.

## comment 4102284163 (src/codegen_fold.c:6819)

_🎯 Functional Correctness_ | _🟠 Major_ | _⚡ Quick win_


**Match keyword names only against declared keyword parameters.**

`emit_call_arity_check` treats every parameter name as keyword-matchable when the callee declares keywords. Therefore, `f(x: 2)` and `f(1, x: 2)` can bypass the correct positional and unknown-keyword checks for `def f(x, k: 1)`. For `def req_kw(x, k:)`, `req_kw(k: 2)` reports `missing keyword: :x` instead of the positional arity error.

Apply the predicate in both checks:










