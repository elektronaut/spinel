# 09-hash-through-getters — report

Five root causes, five branches, each off upstream/master 032c037a with its
own test. All six reproducers pass with the branches combined; each branch
fixes exactly its own reproducers.

| bug | branch | commit | diff stat |
|---|---|---|---|
| brackish-wryneck (`def cache = super`) | `fix-hash-through-getters-super` | 6f62e941 | 3 files, +118 −29 |
| vernal-siskin (`x = c.cache; x["x"] = …`) | `fix-hash-through-getters-alias` | f660bff3 | 3 files, +84 |
| wry-merlin (e, e4: direct `@c[:s] = 3.5`) | `fix-hash-through-getters-misfit` | 96a9644e | 3 files, +49 −1 |
| stony-turnstone (Struct member hash) | `fix-hash-through-getters-struct` | 83dce685 | 3 files, +33 |
| oaken-pochard (`c.name[0] = "X"`) | `fix-hash-through-getters-string` | 60b0b08f | 8 files, +158 −9 |

## Root causes

- **super**: `getter_ivar_targets` only took getters whose exits are ivars, so
  a `super` body was no getter and the write was evidence for nothing. It now
  follows a bare `super`/`super()` up the chain. A class carries its parent's
  readers as its own copy, so a subclass method over an inherited reader
  looked like a tie and neither branch won; the method is now the override.
  Every class also keeps its own copy of an inherited ivar's type: crediting
  only the getter's defining class left a base class that writes the ivar
  narrower, and the post-fixpoint up-merge boxed the pair (TypeError on the
  store). The write now credits the copies from the dispatching class up.
  That last part was pre-existing without `super`: a subclass
  `def cache = @c` over a hash the base class fills failed the same way.
- **alias**: `x = c.cache; x[k] = v` was folded into the local alone, typing
  it apart from the ivar it aliases. A hash local whose one write is a getter
  call or an ivar read now redirects the write to that source
  (`local_hash_alias_source`).
- **misfit**: a direct `@c[:s] = 3.5` into an ivar hash other sites (the
  `(@c ||= {})` getter writes) had settled Integer-keyed was refused by
  `fold_container_evidence` and silently dropped; the fold can also trade an
  Integer key for a String one. The direct-ivar path now widens to PolyPoly,
  with the ivar's literals, on such a misfit, as the getter path already did.
- **struct**: `S.new({})` built the empty literal as its own default
  (StrPoly) while the member widened to PolyPoly; the literal's `hash_want`
  now follows the member's settled variant (`struct_new_types_members`).
- **string**: `[]=` (and `insert`) were not in `SP_MUT_IVAR`, so the reader
  never handed out the shared handle, and no codegen arm took a reader call
  as receiver. They now demand the handle, and a shim over the reader call
  (`sb_reader_shim_open`) substitutes a shadow for the call node via the
  argument-override table and re-runs the value arm, in statement and value
  position, like the local/ivar shims.

## Gate

Run separately on each branch, `LANG=C.UTF-8`, `make -k -j4 gate TEST_JOBS=-j4`.
Identical on all five:

```
Tests: 3996 pass, 2 fail, 0 error
FAIL: pkg.tmpdir.tmpdir_expand_usable        (known: root)
FAIL: socket_ipv6_and_class_methods          (known: no UDP)
rubyspec-gate[language]: all 671 expected-PASS examples still pass
rubyspec-gate[core/array]: all 421 expected-PASS examples still pass
rubyspec-gate[core/string]: all 571 expected-PASS examples still pass
rubyspec-gate[core/hash]: all 192 expected-PASS examples still pass
rubyspec-gate[core/integer]: all 171 expected-PASS examples still pass
rubyspec-gate[core/range]: all 83 expected-PASS examples still pass
Benchmarks: 62 pass, 0 fail, 0 error, 0 skip
spin-e2e: ALL GREEN; infer-test, diff-test and the other *-test targets: pass
```

## Surprising / left alone

- An alias taken before a String mutation through a reader does not see it:
  after `x = c.name`, `c.name << "!"` (or `[0] = "X"`) leaves `x` unchanged.
  Pre-existing on master for `<<`; the external-reader-alias pass (#3227 P5)
  misses it. Not fixed.
- `slice!` and `setbyte` through a reader are still silently dropped, as on
  master: they need value-position shims (slice!'s String/Range forms, and an
  `emit_scalar_call` shim for setbyte). I tried enabling them and backed it
  out. A class using `setbyte` on the ivar anywhere also disables handle
  promotion for it, which drops `[]=`/insert through its reader too.
- The fold overwriting an Integer-keyed hash slot with a String-keyed one is
  still how locals behave; the alias redirect sidesteps it for aliases and the
  misfit widening guards ivars.
