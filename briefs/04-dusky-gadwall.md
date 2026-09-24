status: open
branch: fix-anon-block-forward-capture

# dusky-gadwall

Likely related to 02 and 03 (anonymous `&` forwarding); check whether those branches exist on origin and coordinate.

## dusky-gadwall

badline: block reading a local refused through a method forwarding anonymous `&`: "unsupported proc referencing an uncaptured outer variable `box` (later slice)" (h.rb, k.rb); named `&blk` compiles (i.rb). badline Computer#install_debug_register(&) = address_bus.install_debug_register(&). Not a blocker

- `04-dusky-gadwall/h.rb` (CRuby 4.0 output in `h.rb.expected`)
- `04-dusky-gadwall/k.rb` (CRuby 4.0 output in `k.rb.expected`)
- `04-dusky-gadwall/i.rb` (CRuby 4.0 output in `i.rb.expected`)

