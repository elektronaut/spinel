# cloud-bug-triage

Communication channel between the local spinel triage session and cloud
sessions. This branch holds no code, only briefs and reports.

- `briefs/<handle>.md` — one bug per file, written by the triage session.
  The first line is `status: open | claimed | done | blocked`.
- `reports/<handle>.md` — written by the cloud session that took the brief.

## Protocol for a cloud session

1. Claim a brief:
   - `git fetch origin cloud-bug-triage && git switch cloud-bug-triage`
   - Pick the first brief in `briefs/` (by filename order) whose status is `open`.
     If you were told a handle, take that one.
   - Change its first line to `status: claimed`, commit ("claim <handle>"), and
     push. If the push is rejected, run `git pull --rebase`. If someone else
     claimed the same brief, pick another one.
2. Set up the code in a separate worktree, so this branch stays checked out:
   - `git remote add upstream https://github.com/matz/spinel.git` (skip if it exists)
   - `git fetch upstream`
   - `git worktree add -b <branch from brief> ../work upstream/master && cd ../work`
   - `make deps && make -j` (the compiler is `bin/spinel`)
3. Do the work the brief describes. The standard fix loop is:
   1. Confirm the reproducer fails: `bin/spinel repro.rb -o /tmp/r && /tmp/r`.
      Compare against the expected output given in the brief.
   2. Fix the root cause in `src/` or `lib/`. Don't special-case the reproducer.
   3. Add the reproducer and one or two variants as `test/<name>.rb`, with the
      expected-output file in the format the neighboring tests use.
   4. Run `make -k -j4 gate TEST_JOBS=-j4`. Two infer-test rows mentioning #4847
      fail on master too; ignore them. Anything else failing must be fixed or
      explained.
   5. Commit with a one-line subject in the repo's style (see `git log`), a short
      body naming the cause, and this trailer:
      `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`
   6. `git push origin <branch>`
4. Report:
   - Write `reports/<handle>.md` on this branch. Include the root cause in 2–4
     sentences, the fix branch and commit sha, the diff stat, the gate summary
     lines, and anything surprising.
   - Set the brief's status to `done`. If you couldn't fix it, use `blocked`,
     and the report says what you learned and where you got stuck.
   - Commit and push. On rejection, `git pull --rebase` and push again.

## Rules

- Never open a PR or an issue, on any repository. The triage session files the
  issue and opens the PR.
- Never push to `master` or to a branch you didn't create.
- One brief per session unless told otherwise.
