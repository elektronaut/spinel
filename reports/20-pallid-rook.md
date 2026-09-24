# pallid-rook: report

**Status:** done
**Branch:** `fix-ffi-callback-prototype` (on origin, based on upstream/master `234125c5`)
**Commit:** `168e103750bb816c88629457936b43b79f530ac1`: "A callback-taking ffi_func is declared under its own extern"

## Root cause

`codegen.c` skipped the extern for any `ffi_func` taking an `ffi_callback`. The
assumption was that a system header declares it, and that our own prototype
would conflict with the header's. The call site then used the bare symbol
name. For a function that no included header declares (`lfind`, from
`<search.h>`), the call had no prototype at all. C falls back to an implicit
`int` return, so a `:ptr` result is truncated to 32 bits. gcc 13 only warns;
gcc 14+ and clang reject it. The conflict the skip worked around no longer
exists: every other `ffi_func` is declared under a private name
(`sp_ffi_f<N>_<sym>`), bound to the real symbol with an `__asm__` label.

## Fix

- **`codegen.c`:** callback-taking functions get the same private-name extern.
  A callback parameter is typed as the trampoline's own pointer type,
  `ret (*)(ffi_cb_arg_ctype...)`, so `&__sp_ffi_cb_N` matches it exactly.
- **`codegen_call.c`:** the call always goes through the extern, except a
  variadic function with no fixed arguments, which has no prototype to write,
  as before. The `(void *)` argument casts that existed only for bare header
  calls are removed. `hdr_call` becomes `takes_cb`, and it now only keeps a
  callback-taking function out of `blocking:` calls, since the callback may
  run Ruby.

## Diff stat

```
 src/codegen.c                               | 22 ++++++++++++---------
 src/codegen_call.c                          | 30 ++++++++---------------------
 test/ffi_callback_no_header.rb              | 12 ++++++++++++
 test/ffi_callback_no_header.rb.expected     |  1 +
 test/ffi_callback_no_header_ptr.rb          | 25 ++++++++++++++++++++++++
 test/ffi_callback_no_header_ptr.rb.expected |  4 ++++
 6 files changed, 63 insertions(+), 31 deletions(-)
```

### Tests

- **`ffi_callback_no_header.rb`:** the brief's reproducer. Its `.expected` is
  `true` (see below).
- **`ffi_callback_no_header_ptr.rb`:** `lsearch` and `lfind` returning a real
  heap pointer. Heap pointers lie above 4 GB on x86-64, so here the truncation
  shows. On master, gcc prints `true false false true` with four
  `-Wint-to-pointer-cast` warnings; with the fix it prints four `true` and no
  warnings.

I also ran every test using `ffi_func`/`ffi_callback` (37, including the two
new ones) with `--cc=clang` (clang 18). All pass with the fix. On master the
pointer variant fails there too (`-Wint-to-void-pointer-cast`).

## Gate (`LANG=C.UTF-8 make -k -j4 gate TEST_JOBS=-j4`)

```
Tests: 4009 pass, 2 fail, 0 error
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
The two failures are the README's known sandbox ones.

## Surprising

- **The brief's `.expected` is CRuby raising `NoMethodError`** for
  `ffi_callback`, which is a Spinel-only API. It can't be the expected output,
  so the test's `.expected` is Spinel's correct answer, `true`.
- **The reproducer printed `true` on master anyway.** NULL survives truncation
  to `int`, so it only shows the bug as a compiler warning. That's why the
  `_ptr` variant exists.
- **SDL2-style callback APIs:** callback parameter types now come from the
  callback's own spec. The private name means a header whose prototype spells
  the parameters differently (`Uint8 *` and so on) can't conflict with it.
