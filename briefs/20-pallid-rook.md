status: open
branch: fix-ffi-callback-prototype

# pallid-rook

FFI: may matter for SDL2 callback APIs. The container needs the C library headers; lfind is in libc.

## pallid-rook

callback-taking `ffi_func` with no header prototype (e.g. `lfind` from <search.h>) gets an implicit `int` declaration: a `:ptr` result is truncated (may matter for SDL2 callback APIs)

- `20-pallid-rook/adj_callback_no_header.rb` (CRuby 4.0 output in `adj_callback_no_header.rb.expected`)

