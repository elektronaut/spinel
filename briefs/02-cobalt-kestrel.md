status: claimed
branch: fix-forwarded-block-ivar-write

# cobalt-kestrel

Silent miscompile. Top priority.

## cobalt-kestrel

FIRST: silent miscompile. A block forwarded via anonymous `&` through one method to another that stores it loses ivar writes to the defining object (CRuby 7, Spinel 0). Likely the gilded-teal/dusky-gadwall family.

- `02-cobalt-kestrel/r21.rb` (CRuby 4.0 output in `r21.rb.expected`)

