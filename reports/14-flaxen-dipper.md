# flaxen-dipper: report

**Status:** done
**Branch:** `fix-array-new-block-string-local` (on origin, based on upstream/master `8522fdb0`)
**Commit:** `9152759577ceb2ce3e39b0764448fb8e50a10a23` — "A value-position write to a mutable-string local wraps its value"

## Root cause

A nested block that appends to `line` makes it a shared mutable-string local
(TY_STRBUF, an `sp_String *` handle). `Array.new(n) { }` emits every non-tail
statement of its block with `emit_expr`, so `line = +""` went through the
*expression* form of a local write (`codegen_expr.c`, `({ lv = rhs; lv; })`).
That form had no STRBUF arm and put the raw `const char *` into the slot. Its
ivar twin already had one (#3993/#4567), and so did the statement form
(`emit_assign`). The expression form now calls `emit_assign` for a STRBUF
local, so aliasing, boxed element reads and the fresh wrap all behave as in the
statement form. Its value is the slot's read face (a string copy), like the ivar twin's.

## Diff stat

```
 src/codegen_expr.c                            | 16 ++++++++++++
 test/array_new_block_strbuf_local.rb          | 36 +++++++++++++++++++++++++++
 test/array_new_block_strbuf_local.rb.expected |  4 +++
 3 files changed, 56 insertions(+)
```

The test (expected output from `ruby`) covers: the brief's shape; `String.new`
over several rows; an alias `b = a` in the block whose mutation shows through
both names; and the write used as an `if` condition. All four failed to compile
on master.

## Gate (`make -k -j4 gate TEST_JOBS=-j4`, LANG=C.UTF-8)

```
Tests: 4005 pass, 2 fail, 0 error
  FAIL: pkg.tmpdir.tmpdir_expand_usable      (known: root in container)
  FAIL: socket_ipv6_and_class_methods        (known: no UDP in sandbox)
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

## Not fixed: write-as-argument to a mutable-string param (also fails on master)

```ruby
def show(s) = s.length
buf = nil
n = show(buf = +"abc")
3.times { buf << "d" }
p [n, buf]        # CRuby [3, "abcddd"]
```
The generated C doesn't compile: `sp_String * _t2 = _t1` where `_t1` is `const char *`.
The argument path types the write node as String and binds it to `show`'s
STRBUF parameter without wrapping. A plain `show(+"xy")` and a non-STRBUF
`show(t = "zz")` both work, so the gap is that argument arm's handling of a
write node. I left it alone: it's in the call-argument code, not the write.
