status: done
branch: fix-kwdefault-poly-ivar-narrowing

# amber-shrike

Silent type narrowing that becomes a run-time TypeError.

## amber-shrike

a keyword default from a poly ivar is narrowed to another call site's explicit arg type, giving TypeError at run time (ActionReplay `romh: @rom`). badline works around it with an untyped RBS seed.

- `05-amber-shrike/r30.rb` (CRuby 4.0 output in `r30.rb.expected`)

