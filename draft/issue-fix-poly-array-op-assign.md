title: `-=`, `|=`, `&=` or `+=` on a mixed-type array with an array of one type on the right is refused or fails the C build

An op-assign on a slot holding a mixed-type array (`m = [1, "x"]`) with a single-type array literal on the right (`m -= ["x"]`) doesn't compile, while the binary spelling `m = m - ["x"]` works. The same holds for `|=`, `&=` and `+=`, and for Integer, String and Float arrays on the right. On a global or an ivar the generated C doesn't build:

```ruby
$m = [1, "x"]
$m -= ["x"]
p $m
@m = [1, "x"]
@m -= ["x"]
p @m
```

CRuby prints `[1]`, `[1]`. Spinel fails the C build: `error: invalid operands to binary - (have ‘sp_PolyArray *’ and ‘sp_StrArray *’)`.

On a local, Spinel refuses the program:

```ruby
m = [1, "x"]
m -= ["x"]
p m
```

CRuby prints `[1]`. Spinel refuses: `unsupported operator assignment: node 6 (LocalVariableOperatorWriteNode)`.

`emit_array_op_assign` in `src/codegen_stmt.c`, which handles array op-assigns on locals, ivars, globals and class variables, requires the right-hand side of `-=`, `|=`, `&=` and `+=` to be the slot's own array kind. The binary `poly_array OP typed_array` arms in `src/codegen_call_recv.c` accept a typed array on the right, but the op-assign doesn't, so a local is refused and an ivar or global falls through to the raw C operator between two array pointers.
