status: open
branch: fix-seeded-array-ivar

# badline-seeds

badline bugs that appear only with a true RBS seed. Compile with the sig dir next to each reproducer: `bin/spinel --rbs <brief dir>/sig_replace replace_pinned.rb` and `--rbs <brief dir>/sig_b seeded_empty_default.rb`. The .expected files are CRuby output, which ignores the seed.

## inky-linnet

badline A: with a true `@storage: Array[Integer]` seed, `@storage.replace(fill(initial))` (fill dups a default-`[]` param, fills with `\

- `16-badline-seeds/replace_pinned.rb` (CRuby 4.0 output in `replace_pinned.rb.expected`)
- `16-badline-seeds/sig_replace/` (RBS seed dir)

## mulberry-fieldfare

badline B: true Array[Integer] ivar seed, assigned from a helper only ever given the empty `[]` default via a subclass's bare super: C error IntArray from PolyArray

- `16-badline-seeds/seeded_empty_default.rb` (CRuby 4.0 output in `seeded_empty_default.rb.expected`)
- `16-badline-seeds/sig_b/` (RBS seed dir)

