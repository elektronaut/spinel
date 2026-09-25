title: A mutable-string local assigned inside an `Array.new` block and appended to by a nested block breaks the C build

When a block given to `Array.new(n)` assigns a local from `+""` (or `String.new`) and a nested block then appends to that local, the generated C doesn't compile. The same code outside `Array.new`'s block works.

```ruby
x = Array.new(1) do |r|
  line = +""
  2.times { line << "a" }
  line
end
puts x[0]
```

CRuby prints `aa`. Spinel fails to build the C: `error: assignment to 'sp_String *' from incompatible pointer type 'const char *'` (the generated line is `({ lv_line = sp_str_dup(...); lv_line; })`).

The nested block's append makes `line` a shared mutable-string local, held as an `sp_String *` handle. `Array.new`'s block emits its non-tail statements as expressions, and the expression form of a local write (the `LocalVariableWriteNode` arm of `emit_expr_node` in `src/codegen_expr.c`) has no case for such a local, so it stores the plain `const char *` value in the `sp_String *` slot.
