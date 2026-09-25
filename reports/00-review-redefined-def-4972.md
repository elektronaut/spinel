# 00-review-redefined-def-4972: report

**Status:** obsolete. PR #4972 was merged at 10:01, and matz fixed the findings
in `405e089c`. The note saying so landed at 10:45, while my gates were running, and
I didn't re-read this branch before pushing. So the two commits below were pushed
after the merge (10:40 and 11:06). They're on the fork branch only and aren't in
upstream/master. I haven't force-pushed or reverted them.

What's still useful:

1. **matz's `405e089c` agrees with this work on all four findings.** It renames the
   earlier body's calls, rewrites the alias target and skips a taken private name.
   It also rejects the singleton suggestion for the same reason as below.
2. **One gap remains on upstream/master (`bcfc3470`): an alias chain over a
   recursive earlier body.** `405e089c` renames the earlier body's calls even when
   an `alias` captured the body. With the usual alias-chain shape, the old body
   then recurses into itself instead of the new definition:

   ```ruby
   def walk(n) = n == 0 ? [:old] : walk(n - 1) + [:old]
   alias walk_old walk
   def walk(n) = walk_old(n) + [:new]
   p walk(2)
   ```

   CRuby prints `[:old, :new, :old, :new, :old, :new]`. Upstream master prints
   `[:old, :old, :old, :new]`. The fix branch at `1a3dd59f` prints CRuby's output,
   because it skips the body rename when an alias captured the body.
   `test/toplevel_def_redefined_recursion.rb` on the fix branch also fails on
   master (its `walk_old(2)` line). If you want it filed, the change is the
   `aliased` part of `1a3dd59f` (about 15 lines in `analyze.c`). It could go on a
   new branch from upstream/master; I haven't made one.

The rest of this report is as written before I saw the note.

Branch `fix-redefined-toplevel-def`. I fetched it at `cb5ddac4` (the amended tip)
and added two commits on top, with no force-push:

| Commit | Subject | Fixes |
|---|---|---|
| `d1833be3d4c05d270fa145b74731f0fdc939e67f` | An alias before a top-level redefinition names the earlier definition | 4102378670 (second finding), 4102378692 (first finding) |
| `1a3dd59f80a9e71658e68eaabf8516c539eeabcf` | An earlier top-level definition's own calls reach it until it is redefined | 4102378670 (first finding) |

The brief lists two findings under each comment id, separated by `---`. I refer to
them as "first" and "second" in brief order. If the second ones have their own ids
on GitHub, the triage session should map them.

## Findings

### 4102378670, first finding (pre-redefinition call target): fixed in `1a3dd59f`

Confirmed: `def nm(n) = n == 0 ? 0 : 1 + nm(n - 1); p nm(3); def nm(n) = 100` printed
`101` (CRuby: `3`). The earlier body's receiverless calls (body and parameter
defaults) are now renamed to its private name as well, because a call can only
reach that body before the redefinition. The one exception is a body captured by an
`alias` between the two defs. That alias can run after the redefinition
(`alias old f; def f = old + 1`), so its calls keep going to the last def. This
follows the reviewer's warning against an unconditional rename.

Reply:

> Fixed in `1a3dd59f`: the earlier definition's own receiverless calls (its body and parameter defaults) now go to its private name, since only the calls before the redefinition reach that body. The exception is a body that an `alias` between the two definitions captured: it can run after the redefinition (`alias old f; def f = old + 1`), so its calls keep reaching the current definition. `test/toplevel_def_redefined_recursion.rb` covers direct recursion, recursion through a block, and the alias case.

### 4102378670, second finding (unused generated name): fixed in `d1833be3`

Confirmed: `def f__redef1 = "user"` followed by two `def f` made `p f__redef1` print
`1`. The pass now skips any `name__redefN` that a `def` anywhere in the program
already uses.

Reply:

> Fixed in `d1833be3`: the private name skips any name a `def` in the program already has, so a program's own `f__redef1` keeps its body next to a redefined `f`. `test/toplevel_def_redefined_alias.rb` covers it.

### 4102378692, first finding (top-level alias): fixed in `d1833be3`

Confirmed: `def f = 1; alias saved f; def f = 2; p saved` printed `2` (CRuby: `1`).
The rename walk now also rewrites the old name of an `alias` it passes between the
two definitions. The alias therefore names the earlier definition's private name,
and the Toplevel alias table resolves to that name.

Reply:

> Fixed in `d1833be3`: an `alias` between a definition and its redefinition now names the earlier definition's private name, so `saved` keeps the body in effect at the alias. `test/toplevel_def_redefined_alias.rb` covers this, including two aliases across three definitions with arguments.

### 4102378692, second finding (singleton scopes in top-level lookup): not valid

CRuby resolves a bare `f` at the top level to the singleton method on `main`:
`def f = 1; def self.f = 2; p f` prints `2`, and so does the reverse order. Filtering
class-method scopes out of the bare lookup would therefore select the wrong body.
Spinel can't compile either order on upstream/master or on this branch. Both
scopes are emitted as `sp_f`, and the C compiler reports `redefinition of 'sp_f'`.
The lookup order this PR changed is never observed for such a program. When only
`def self.h` exists, master and the branch both fail bare `h` with `NoMethodError`
while CRuby prints `5`, so that behavior predates this PR too.

Reply:

> Not changed: at the top level CRuby resolves a bare `f` to the singleton method on `main` when both `def f` and `def self.f` exist (`def f = 1; def self.f = 2; p f` prints `2`), so filtering singleton scopes out of the bare lookup would select the wrong body. Such a program doesn't compile on master or on this branch either way, because both scopes are emitted as `sp_f` and C reports a redefinition, so the lookup order this PR changes is never observed.

## Tests

- `test/toplevel_def_redefined_alias.rb` (`d1833be3`): aliases across two and
  three definitions, and a program-defined `f__redef1`. It fails at `cb5ddac4`
  (prints `2 2 0 1 2 3 1 …`) and on master (C compile error). It matches CRuby with
  the fix.
- `test/toplevel_def_redefined_recursion.rb` (`1a3dd59f`): recursion, recursion
  through a `map` block, and an alias that runs after the redefinition. It prints
  `101 100 -5 -1 …` at `d1833be3`, fails on master with a C compile error
  (`conflicting types for 'sp_count'`), and matches CRuby with the fix.
- The existing `test/toplevel_def_redefined.rb` still passes.

## Gate

Gate 1 (tree of `d1833be3`), `make -k -j4 gate TEST_JOBS=-j4` with `LANG=C.UTF-8`:

```
Tests: 4010 pass, 2 fail, 0 error      (pkg.tmpdir.tmpdir_expand_usable, socket_ipv6_and_class_methods: both known)
Benchmarks: 62 pass, 0 fail, 0 error, 0 skip
Optcarrot: OK
spin-e2e: ALL GREEN
rubyspec-gate[language]: all 671 expected-PASS examples still pass
rubyspec-gate[core/array]: all 421 expected-PASS examples still pass
rubyspec-gate[core/string]: all 571 expected-PASS examples still pass
rubyspec-gate[core/hash]: all 192 expected-PASS examples still pass
rubyspec-gate[core/integer]: all 171 expected-PASS examples still pass
rubyspec-gate[core/range]: all 83 expected-PASS examples still pass
```

Gate 2 (tree of `1a3dd59f`), same command:

```
Tests: 4011 pass, 2 fail, 0 error      (the same two known failures)
Benchmarks: 62 pass, 0 fail, 0 error, 0 skip
Optcarrot: OK
spin-e2e: ALL GREEN
rubyspec-gate[language]: all 671 expected-PASS examples still pass
rubyspec-gate[core/array]: all 421 expected-PASS examples still pass
rubyspec-gate[core/string]: all 571 expected-PASS examples still pass
rubyspec-gate[core/hash]: all 192 expected-PASS examples still pass
rubyspec-gate[core/integer]: all 171 expected-PASS examples still pass
rubyspec-gate[core/range]: all 83 expected-PASS examples still pass
```

Gate 2 ran in a second worktree while gate 1 finished. The committed tree
differs from the gated one only in how one comment is wrapped. After that
rewrap I rebuilt and reran `toplevel_def_redefined*`,
`builtins_take_drop_while` and `module_reopen_cmeth_redefine`, and all pass.
Both gates finished before pushing. Pushed at 10:40 (`d1833be3`) and 11:06
(`1a3dd59f`), before the 11:20 deadline.

Diff stats:

```
d1833be3  src/analyze.c | 17 ++++-, test/toplevel_def_redefined_alias.rb | 27 +, .expected | 9 +   (3 files, +52 -1)
1a3dd59f  src/analyze.c | 35 +++---, test/toplevel_def_redefined_recursion.rb | 22 +, .expected | 6 +   (3 files, +52 -11)
```

## Surprising

- Another session (cloud-1) claimed both review briefs in one commit at 09:52.
  The claim on this brief was later released ("unclaim ... for another worker"),
  and I took it at 09:55.
- `d1833be3` has a `Refs #4971` line where FILING.md asks for `Fixes #4971`. The
  branch's first commit already carries `Fixes #4971`, and I didn't amend, because
  the brief forbids force-pushing.
- Top-level `def f` plus `def self.f` is a C redefinition on master (see above).
  It may be worth filing separately. It's out of scope for this PR.
- Not covered by the recursion fix: a closure created in the earlier body that
  escapes and runs after the redefinition still calls the earlier body. Another
  top-level method called before the redefinition that itself calls `nm` still
  reaches the last definition. Both need version-aware dispatch.
