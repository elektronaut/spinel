status: claimed
branch: fix-super-accessor-mid-redeclare

# sooty-godwit

Super into a writer when a middle class re-declares the accessor: Leaf's `super` must reach Mid's attr_writer, but Spinel calls Parent's def. A residual of #4909.

## sooty-godwit

super into accessor edge: Grand attr_accessor, Parent def override, Mid redeclares the accessor, Leaf super calls Parent's def (CRuby writes the ivar). Left alone by #4909

- `12-sooty-godwit/sooty.rb` (CRuby 4.0 output in `sooty.rb.expected`)

