# hazel-pipit: report

**Status:** done
**Branch:** `fix-rubyspec-extract-locale` (on origin, based on upstream/master `032c037a`)
**Commit:** `72a4673eee2ff85bd1ab2a25375bc48bebc2e0ad`: "The rubyspec extractor reads specs as UTF-8, and the gate fails on a short run"

## Root cause

Three layers hid each other:
1. Under an empty or C locale, `extract.rb` read the spec files as US-ASCII.
   `String#strip` raised at the first non-ASCII line, which aborted the whole
   glob. `language` extracted 498 of 2399 examples.
2. `run.sh` correctly exits 2 when a listed example is missing, but the
   `rubyspec-gate` recipe ignored both its status and the extractor's.
3. With no results file, `awk ... | wc -l` gave 0 "regressions", so the gate
   printed `all N expected-PASS examples still pass`.

## Fix

- `extract.rb`: `Encoding.default_external = Encoding::UTF_8` at the top. The
  extracted output is byte-identical under `LANG=` and `LANG=C.UTF-8` for all
  six enrolled suites (same file count and same md5 of the concatenated
  output).
- `rubyspec-gate`: a suite fails if extraction fails, if `run.sh` fails, or if
  the results TSV has fewer rows than the expected-PASS list. The stale TSV is
  removed first so an old one can't stand in.
- `rubyspec` (the measurement target): an extractor failure now stops it
  (`|| exit 1`) instead of measuring a partial extraction.

Negative check: with the old extractor and `LANG=`,
`make rubyspec-gate RUBYSPEC_SUITES="core/range language"` now prints
`rubyspec-gate[language]: extraction failed` and exits non-zero.

## Diff stat

```
 Makefile                  | 23 ++++++++++++++++++-----
 tools/rubyspec/extract.rb |  5 +++++
 2 files changed, 23 insertions(+), 5 deletions(-)
```

No test file, because this is tooling with no Ruby reproducer. The gate run
below is the test.

## Gate (run deliberately with an **empty** `LANG`, to prove the fix)

```
Tests: 3995 pass, 2 fail, 0 error      (pkg.tmpdir.tmpdir_expand_usable, socket_ipv6_and_class_methods: the known env failures)
Benchmarks: 62 pass, 0 fail, 0 error, 0 skip
Optcarrot: OK
infer-test: pass
spin-e2e: ALL GREEN
extracted 2399 examples into build/rubyspec-ex-language
rubyspec-gate[language]: all 671 expected-PASS examples still pass
rubyspec-gate[core/array]: all 421 expected-PASS examples still pass
rubyspec-gate[core/string]: all 571 expected-PASS examples still pass
rubyspec-gate[core/hash]: all 192 expected-PASS examples still pass
rubyspec-gate[core/integer]: all 171 expected-PASS examples still pass
rubyspec-gate[core/range]: all 83 expected-PASS examples still pass
```

No "listed example missing from extraction" lines appeared.

## Notes

- Once this merges, the README's `export LANG=C.UTF-8` step is no longer
  needed for the gate. It does no harm to keep it.
- Not changed: the non-gate `make rubyspec` measurement runs a CRuby oracle
  (`ruby "$f"`) inside `run.sh`. Under an empty LANG, CRuby's
  `default_external` differs, which could classify some encoding specs
  differently from a UTF-8 run. It only affects the measurement, not the
  gate (the gate sets `RUBYSPEC_GATE=1` and skips the oracle).
