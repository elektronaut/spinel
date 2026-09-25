status: done
branch: fix-redefined-toplevel-def
deadline: 11:20 Oslo (matz merges at 11:28; after 11:20, skip)
pr: 4972

# Review fixes for PR #4972

Fetch the branch first: its tip was amended this morning to add `Fixes #N`.
Fix each finding you can verify, before the deadline, as a new commit on top.
Never force-push. The report lists each finding (by comment id) as fixed,
not valid or skipped, and gives a 1–3 sentence reply for each fixed or
not-valid finding, which the triage session posts.

## comment 4102378670 (src/analyze.c:14170)

_🎯 Functional Correctness_ | _🟠 Major_ | _🏗️ Heavy lift_


**Preserve the pre-redefinition call target without rewriting later invocations.**

When `st[i]` is renamed to `nm__redefN`, `redef_rename_calls` skips its `NK_DefNode`. Receiverless calls in its body and parameter defaults therefore still use `nm`. The top-level resolver binds `nm` to the later definition. A call that enters the earlier definition before the redefinition can therefore recurse into the later body and return an incorrect result.

Do not apply the proposed unconditional traversal of `body` and `parameters`. If the earlier body executes after the redefinition, Ruby resolves its receiverless calls against the current definition. The lowering needs a separate pre-redefinition entry or version-aware dispatch so only calls reached before the redefinition use `nm__redefN`.


</details>





---

_🎯 Functional Correctness_ | _🟡 Minor_ | _⚡ Quick win_


**Choose an unused generated name before renaming.**

A valid program can define `f__redef1` and repeat `f`. The pass then renames the earlier `f` to the existing `f__redef1`. The lookup selects one of the two scopes, and `scope_is_shadowed` suppresses the other scope. This avoids a duplicate C definition, but receiverless calls named `f__redef1` can call the wrong body.

Check all existing top-level definition names, including names assigned by earlier iterations, before calling `nt_set_str`.



</details>






## comment 4102378692 (src/compiler.c:1595)

_🎯 Functional Correctness_ | _🟡 Minor_ | _⚡ Quick win_


**Preserve the definition active at a top-level alias.**

For `def f; 1; end; alias saved f; def f; 2; end`, the rename pass changes the first definition to `f__redef1`, but top-level alias registration still stores `saved -> f`. `comp_method_index` then resolves `saved` to `f` and selects the later definition. `saved` can therefore call the second body instead of the body active at the alias statement.

Update the alias handling so it retains the earlier definition for this top-level case, or rewrites the alias target when the earlier definition is renamed.





---

_🎯 Functional Correctness_ | _🟡 Minor_ | _⚡ Quick win_


**Exclude singleton scopes from ordinary top-level lookup.**

`def self.f` at top level keeps `class_id < 0` and sets `is_cmethod = 1`. Because `comp_method_index` ignores `is_cmethod`, its reverse scan and frozen index can select this singleton scope for a bare `f` call instead of the ordinary top-level `def f`. Filter class-method scopes from both top-level lookup paths.








Priority: the two quick wins first (unused generated name; singleton scopes), then the alias one. The first finding (pre-redefinition call target) is a heavy lift: only if time is left, otherwise mark it skipped.

**Obsolete (10:45):** PR #4972 was merged at 10:01 and matz fixed these findings himself in 405e089c. Stop work on this brief; nothing to push.
