# cloud-bug-triage

Communication channel between the local spinel triage session and cloud
sessions. This branch holds no code, only briefs and reports.

- `briefs/NN-<handle>.md`: one brief per file, written by the triage session.
  The first line is `status: open | claimed | done | blocked`, the second the
  branch name to use. Reproducers live next to it in `briefs/NN-<handle>/`,
  each with a `.expected` file holding CRuby 4.0's output. The container's
  Ruby is older; trust the `.expected` file over it.
- `reports/NN-<handle>.md`: written by the cloud session that took the brief.

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
   - `git config user.name "Inge Jørgensen" && git config user.email inge@elektronaut.no`
   - `make deps && make -j` (the compiler is `bin/spinel`)
   - `export LANG=C.UTF-8`. With an empty LANG, the rubyspec extractor silently
     skips examples and the rubyspec checks under-test while still printing "pass".
3. Do the work the brief describes. The standard fix loop is:
   1. Confirm the reproducer fails: `bin/spinel repro.rb -o /tmp/r && /tmp/r`.
      Compare against the expected output given in the brief.
   2. Fix the root cause in `src/` or `lib/`. Don't special-case the reproducer.
      A hint names one site; look for sibling sites with the same pattern
      (parallel dispatch arms, the zero-arg and n-arg variants) and fix those too.
   3. Add the reproducer and one or two variants as `test/<name>.rb`, with the
      expected-output file in the format the neighboring tests use.
   4. Run `make -k -j4 gate TEST_JOBS=-j4`. It takes over 10 minutes, so run
      it in the background. Known failures that aren't yours:
      - `pkg.tmpdir.tmpdir_expand_usable`: the container runs as root.
      - `socket_ipv6_and_class_methods`: the sandbox has no UDP.
      - on macOS only, two infer-test rows mentioning #4847.
      - spin-e2e prints `warning: push negotiation failed`: it pushes to a
        local temp repo, harmless.
      Anything else failing must be fixed or explained. Commit only after the
      whole gate, rubyspec included, has finished clean.
   5. Commit with a one-line subject in the repo's style (see `git log`), a short
      body naming the cause, and this trailer:
      `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`
      Use exactly that trailer and no other (no `Claude-Session:` line).
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
- A brief listing several bugs may have several root causes. Make one branch
  per root cause (the brief's branch name plus a suffix), each with its own
  tests, and list every branch in the report. Bugs you couldn't fix go in the
  report too, with what you learned.
- If one bug is already fixed on upstream/master, say so in the report and move on.
