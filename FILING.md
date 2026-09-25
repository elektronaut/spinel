# Issue and PR format for matz/spinel

Whoever drafts issue or PR text for matz/spinel (the triage session, a cloud
worker preparing text, or a script) follows this. Examples: issue #4959 and
PR #4960, issue #4954 and PR #4955.

Write plain prose in unwrapped paragraphs, one line per paragraph. Never paste
a commit body (it's hard-wrapped at 72 columns) or a report section verbatim.
Code, identifiers, file names and Ruby snippets go in backticks.

## Issue

1. **Title:** the symptom as a statement of what goes wrong, not the fix.
   "A keyword default reading a poly ivar is narrowed to another call site's
   argument type", not "Fix default narrowing".
2. **Opening paragraph:** what the program does, what goes wrong, and when. Name
   the shape (`def m(x, k: 1)` called as `m(3, 4)`), not the internals.
3. **Reproducer:** the smallest program, in one ```` ```ruby ```` block. If there
   are several shapes, give each its own block with one sentence in front of it.
4. **Outcome line**, directly after the block, in prose:
   "CRuby prints `4`, `2`, `4`, `6`. Spinel raises `wrong argument type Bank
   (expected RAMBank) (TypeError)`." Always both sides, and Spinel's actual
   output or error from current master. A C build error quotes the key line of
   the compiler error. Don't use a separate "CRuby:" output block.
5. **Cause paragraph:** one or two sentences naming where and why it goes wrong
   (function and file are fine). **Don't describe the fix.** No "Cause:" label.

Nothing else: no headings, no handle names, no "found by" lines.

## PR

1. **Title:** the commit subject.
2. **First line:** `Fixes #N.` (several: `Fixes #N, fixes #M.`)
3. **What was wrong:** one paragraph on the mechanism, in more detail than the
   issue's cause paragraph.
4. **What changed:** one paragraph on the fix, plus what deliberately stays
   the same and why it's safe.
5. **Tests:** "Tests: `test/x.rb` is the issue's reproducer. `test/y.rb`
   covers ... Both fail on master and match CRuby 4.0 with this change. `make
   gate` is clean." Say what each test file covers.
6. **Optional, one paragraph each:**
   - "Not covered:" a known gap left for later, with a sentence on why.
   - Where it was found, if a real program hit it (for example, the badline C64
     emulator).

## Commit

The subject is in the repo's style (see `git log`): a present-tense statement of
the corrected behavior. The body is a short cause-and-fix, hard-wrapped. Before
the trailer come `Fixes #N` lines, one per issue, then
`Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
The commit author is Inge Jørgensen.
