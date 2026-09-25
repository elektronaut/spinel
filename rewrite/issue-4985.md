A module that binds a C function taking an `ffi_callback` (`ffi_func :lsearch, [:ptr, :ptr, :ptr, :size_t, :cmp], :ptr`) gets a wrong `:ptr` result when no header Spinel includes declares that function, as with `lfind` and `lsearch` from `<search.h>`. The returned pointer is cut to 32 bits, so a heap address no longer compares equal to itself. A NULL result still comes out right, which hides the bug in the simplest calls. gcc 13 only warns about it; gcc 14 and later and clang reject the implicit declaration. This may matter for SDL2-style callback APIs.

```ruby
module L
  ffi_callback :cmp, [:ptr, :ptr], :int
  ffi_func :calloc, [:size_t, :size_t], :ptr
  ffi_func :lsearch, [:ptr, :ptr, :ptr, :size_t, :cmp], :ptr
end
def never(a, b) = 1

base = L.calloc(4, 8)
key = L.calloc(1, 8)
nel = L.calloc(1, 8)
puts L.lsearch(key, base, nel, 8, method(:never)) == base
```

The program should print `true`, since `lsearch` appends the key and returns the new slot at `base` (CRuby can't run it because `ffi_callback` is Spinel-only). Spinel prints `false`, and gcc warns `cast to pointer from integer of different size [-Wint-to-pointer-cast]` on the `lsearch` line.

`codegen_program` in `src/codegen.c` emits no extern for an `ffi_func` that takes an `ffi_callback`, assuming a system header declares it, and the call site in `src/codegen_call.c` uses the bare symbol name. When no included header declares the function, C falls back to an implicit declaration returning `int`, and the `:ptr` result is truncated.
