status: claimed
branch: fix-string-mutation-through-reader

# string-through-reader (handles: gray-shearwater, tan-longspur). Silent wrong values.

Found by the brief-09 session. Both reproduce on master. They may share a root
cause (how a String ivar is handled when mutated through an attr_reader).

## gray-shearwater: an alias taken before a mutation through a reader doesn't see it

After `x = c.name`, `c.name << "!"` leaves `x` as `"ab"` (CRuby `"ab!"`: same
object). The external-reader-alias pass (#3227 P5) misses it. `[0] = "X"` through
the reader has the same problem.

- `28-string-through-reader/alias_mutation.rb`

## tan-longspur: `slice!` through a reader is silently dropped

`c.name.slice!(0)` leaves the ivar unchanged. The brief-09 session says it needs
value-position shims (slice!'s String/Range forms), and that a class using
`setbyte` on the ivar anywhere disables handle promotion for it, which then drops
`[]=`/insert through its reader too. Cover `setbyte` in a variant.

- `28-string-through-reader/slice_bang.rb`
