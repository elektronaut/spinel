status: claimed
branch: fix-hash-through-getters

# hash-through-getters

Hash/String ivars written through getters. Probably one or two root causes in the ivar write-evidence analysis.

## brackish-wryneck

`def cache = super` getter not followed for write evidence

- `09-hash-through-getters/super_getter.rb` (CRuby 4.0 output in `super_getter.rb.expected`)

## stony-turnstone

Struct member hash with mixed keys: C error

- `09-hash-through-getters/struct.rb` (CRuby 4.0 output in `struct.rb.expected`)

## vernal-siskin

local alias of a getter (`x = c.cache; x["x"] = "y"`) with another key type: C error

- `09-hash-through-getters/d3.rb` (CRuby 4.0 output in `d3.rb.expected`)

## oaken-pochard

`String#[]=` through a getter raises NoMethodError

- `09-hash-through-getters/string_ivar.rb` (CRuby 4.0 output in `string_ivar.rb.expected`)

## wry-merlin

direct Symbol-keyed write into an ivar hash also written through an `(@c

- `09-hash-through-getters/e.rb` (CRuby 4.0 output in `e.rb.expected`)
- `09-hash-through-getters/e4.rb` (CRuby 4.0 output in `e4.rb.expected`)

