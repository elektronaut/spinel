status: open
branch: fix-surplus-arg-refusal

# arity-refusals

Calls CRuby refuses with ArgumentError that Spinel binds silently. Likely one shared check in the direct-call argument binder.

## mossy-lynx

surplus positional into a keyword param not refused (`def m(x, k: 1); m(3, 4)` -> [3, 1])

- `06-arity-refusals/direct_mix.rb` (CRuby 4.0 output in `direct_mix.rb.expected`)

## willow-bison

surplus positionals into `**kw` not refused (`def f(x, **kw); f(3, 4)`)

- `06-arity-refusals/kwrest_surplus.rb` (CRuby 4.0 output in `kwrest_surplus.rb.expected`)

## violet-mole

unknown keyword bound positionally instead of ArgumentError (`def g2(x, y = 7, k: 1); g2(1, j: 2)`)

- `06-arity-refusals/unknown_kw_positional.rb` (CRuby 4.0 output in `unknown_kw_positional.rb.expected`)

