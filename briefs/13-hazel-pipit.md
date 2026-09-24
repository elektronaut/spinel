status: claimed
branch: fix-rubyspec-extract-locale

# hazel-pipit

Tooling bug, no reproducer file: run `LANG= make gate-rubyspec` and look for `invalid byte sequence in US-ASCII` from tools/rubyspec/extract.rb.

## hazel-pipit

tools/rubyspec/extract.rb:66 raises "invalid byte sequence in US-ASCII" under an empty LANG, some examples are never extracted, and gate-rubyspec still prints "all N pass". Fix: force UTF-8 in the extractor and fail the gate when extraction fails. Reported by the zinc-shrew cloud session.


