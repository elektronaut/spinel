# sooty-godwit: report

**Status:** done
**Branch:** `fix-super-accessor-mid-redeclare` (on origin, based on upstream/master `032c037a`)
**Commit:** `61de1cc5e776660fb56db0d003fa0991b6588df5` — "An inherited attribute stops at a subclass that overrides it with a def"

## Root cause

`inherit_members` (analyze_scope.c) copied every reader/writer flag from a
parent into each subclass, even a subclass that overrides the name with its own
`def`. Parent therefore held Grand's writer flag under its `def x=`, and Mid
held it a second time. `super_lands_on_attr` (#4909) treats "the parent holds
it too" as "this class only inherited it". So it walked past Mid's own
`attr_writer` and reached Parent's def. Now a flag isn't copied into a class
that defines the method itself, so the def ends the attribute's inheritance.

## Surprising: a worse sibling, no super needed

The same stale flag made a **plain call** on any class below the def read the
attribute instead of the def:
```ruby
class DGrand; attr_accessor :z; end
class DParent < DGrand; def z=(v) = @z = v * 10; def z = @z + 1; end
class DOther < DParent; end
o = DOther.new; o.z = 3; p o.z     # CRuby 31, master 3
```
Silent wrong value. Fixed by the same change and covered in the test.

## Diff stat

```
 src/analyze_scope.c                       | 14 ++++++-
 test/super_attr_mid_redeclare.rb          | 64 +++++++++++++++++++++++++++++++
 test/super_attr_mid_redeclare.rb.expected |  4 ++
 3 files changed, 80 insertions(+), 2 deletions(-)
```

Test `super_attr_mid_redeclare.rb` (expected output from `ruby`): the brief's
writer case, the reader form through `super`, a redeclaring subclass read
through the def, and the plain-subclass case above. On master it prints
30/501/3/3; CRuby and this branch print 3/6/4/31. The existing
`super_into_attr` test (#4909) still passes.

## Gate (`make -k -j4 gate TEST_JOBS=-j4`, LANG=C.UTF-8)

```
Tests: 3996 pass, 2 fail, 0 error
  FAIL: pkg.tmpdir.tmpdir_expand_usable      (known: root in container)
  FAIL: socket_ipv6_and_class_methods        (known: no UDP in sandbox)
Benchmarks: 62 pass, 0 fail, 0 error, 0 skip
Optcarrot: OK
infer-test: pass
spin-e2e: ALL GREEN   (with the known "push negotiation failed" warning)
rubyspec-gate[language]: all 671 expected-PASS examples still pass
rubyspec-gate[core/array]: all 421 expected-PASS examples still pass
rubyspec-gate[core/string]: all 571 expected-PASS examples still pass
rubyspec-gate[core/hash]: all 192 expected-PASS examples still pass
rubyspec-gate[core/integer]: all 171 expected-PASS examples still pass
rubyspec-gate[core/range]: all 83 expected-PASS examples still pass
```

The fix only looks at the class's own `def`, via `comp_method_in_class`. A
`def` that comes from a module included into the middle class isn't
considered; I didn't probe that shape.
