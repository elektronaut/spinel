# sepia-dotterel: report

**Status:** done (does not reproduce: no fix branch, nothing pushed)

## Finding

Both reproducers print the CRuby 4.0 expected output (`7`, `42`) on:
- upstream/master `5e6a2e1c` ("An any?/all?/none?/one? loop answers boxed when its call is typed boxed")
- origin/master `70b2be32` (Merge #4950), the older base the other 0x briefs were written against

Built on Linux (cc, `make -j`) and run as `bin/spinel X.rb -o /tmp/x && /tmp/x`.

The brief's description is cut off after "module method's `@h", so I couldn't
check the exact symptom it describes. Going by the branch name
(`fix-module-ivar-hash-getter`), I also probed getter-shaped variants. All of
them match CRuby:
- `def traps = (@traps ||= {})` in a module, with `traps[addr] = handler` / `traps[@pc]&.call` from an including class
- `attr_reader :traps` declared in the module, with `@traps ||= {}` then `traps[addr] = handler`
- one module with a memoized `@regs ||= {}` getter included into two classes whose hashes hold different value types
- a module-level (`def self.`) memoized `@table ||= {}` holding procs

## If it still fails for you

It may depend on the platform (macOS clang) or on a detail the truncated
description held. Please re-brief with the full symptom text (refusal message
or wrong output) and the platform. I didn't create the branch, so the handle
is free to reuse.
