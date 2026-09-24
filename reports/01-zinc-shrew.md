# zinc-shrew: report

**Status:** done
**Branch:** `fix-poly-recv-default-ivar` (on origin, based on upstream/master `70b2be32`)
**Commit:** `4dda38a133179565779bb150e69e79f61f4309b3` — "A poly-receiver arm's default reads ivars off a parenthesized self"

## Root cause

`emit_poly_method_dispatch` builds each arm's receiver as `(sp_B *)_t.v.p` and
sets `g_self` to that string while it emits the callee's defaults. An ivar
default is spelled `<g_self><g_self_deref>iv_x`, so the output was
`(sp_B *)_t.v.p->iv_extra`. The cast binds looser than `->`, so `->` applied to
the `void *` first and the C didn't compile. The same bug was in **both** arms:
the one for methods with required params (`codegen_call.c` ~7832, the brief's
reproducer) and the one for zero-required-param methods (~6553). The brief only
covered the first.

## Fix

In both arms, a struct receiver is now handed to the defaults as
`((sp_B *)_t.v.p)`, and `g_self_deref` is pinned to `->` while they're emitted.
It is restored afterward. The primitive receivers (`.v.i`/`.v.f`/`.v.s`/`sp_sym`)
are unchanged. Because the deref is pinned, a by-value class also reads its ivars
through the pointer form. Before, the zero-arg arm passed `*(sp_V *)...` as
`g_self`, and a caller whose own self is by-value leaked `.` into the arm. The
argument passed to the call itself is unchanged.

## Diff stat

```
 src/codegen_call.c                               | 34 +++++++++++----
 test/poly_recv_default_ivar.rb                   | 14 ++++++
 test/poly_recv_default_ivar.rb.expected          |  2 +
 test/poly_recv_default_ivar_variants.rb          | 55 ++++++++++++++++++++++++
 test/poly_recv_default_ivar_variants.rb.expected |  7 +++
 5 files changed, 104 insertions(+), 8 deletions(-)
```

Tests: the brief's reproducer, plus a variants file. The variants cover a
default that calls a method on the ivar (`@name.upcase`, `@label.length`), a
three-class hierarchy (`@c * 2`), and the zero-required-param arm. Both
expected files match CRuby's output. The variants file failed to compile on
unpatched master (7 C errors).

## Gate (`make -k -j4 gate TEST_JOBS=-j4`)

```
Tests: 3993 pass, 2 fail, 0 error
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

The two failures are caused by the environment. Both fail the same way with the
unpatched compiler:

- `pkg.tmpdir.tmpdir_expand_usable` prints `false/true/false` where `true` is
  expected. The container runs as root, so `chmod 0500` doesn't make the
  directory unwritable.
- `socket_ipv6_and_class_methods` fails with `cannot create UDP socket
  (SocketError)` because the sandbox has no UDP.

## Surprising

- `infer-test` **passed**. The two #4847 rows the README says fail on master
  didn't show up here.
- With the container's empty `LANG`, `tools/rubyspec/extract.rb:66` raises
  `invalid byte sequence in US-ASCII`. The rubyspec legs still print "all N
  pass", but some extraction is missing (for example,
  `build/rubyspec-gate-core-range.tsv` isn't written and range examples are
  "missing from extraction"). The rubyspec lines above come from rerunning
  `gate-rubyspec` with `LANG=C.UTF-8`, which is clean. It may be worth forcing
  a UTF-8 external encoding in `extract.rb` so it doesn't depend on the locale.
- `spin-e2e` runs `git push` to a bare repo under `/tmp`, which prints a
  harmless "push negotiation failed" warning. Nothing reaches a real remote.
