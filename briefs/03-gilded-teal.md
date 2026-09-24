status: open
branch: fix-new-block-forwarding

# gilded-teal

Both items are about a block reaching `Klass.new`. They probably share a root cause; if not, one branch each.

## gilded-teal

badline: block forwarded with anonymous `&` into a constructor arrives nil: `def install(&) = Reg.new(&)` -> "undefined method 'call' for nil" (f.rb); named `&blk` -> C error "undeclared identifier 'lv_blk'" (b.rb). badline AddressBus#install_debug_register -> DebugRegister.new(@sid, &). Not a blocker (worked around in spinel/debug_register.rb)

- `03-gilded-teal/f.rb` (CRuby 4.0 output in `f.rb.expected`)
- `03-gilded-teal/b.rb` (CRuby 4.0 output in `b.rb.expected`)

## pewter-crake

`Klass.new(&)` drops the block; `Klass.new(&block)` fails with undeclared lv_block; a literal block to `new` reading an outer block param is refused. Merge into gilded-teal if same root.

- `03-gilded-teal/r13.rb` (CRuby 4.0 output in `r13.rb.expected`)
- `03-gilded-teal/r14.rb` (CRuby 4.0 output in `r14.rb.expected`)
- `03-gilded-teal/r16.rb` (CRuby 4.0 output in `r16.rb.expected`)

