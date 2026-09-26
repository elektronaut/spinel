title: A String ivar mutated through its attr_reader lands in a copy, or the mutation is lost

A class holds a mutable String in an ivar and exposes it with `attr_reader :name`. Mutating it through the reader from outside the class (`c.name << "!"`, `c.name.slice!(0)`) should change the one String every reader and alias sees. In Spinel, an alias taken from the reader beforehand keeps the old value, `slice!` through the reader is silently dropped, and once the class itself uses `setbyte`, `slice!`, `[]=` or `insert` on the ivar, even `<<` through the reader is lost.

An alias taken before a mutation through the reader:

```ruby
class C
  attr_reader :name
  def initialize = @name = +"ab"
end
c = C.new
x = c.name
c.name << "!"
p x
p c.name
```

CRuby prints `"ab!"`, `"ab!"`. Spinel prints `"ab"`, `"ab!"`.

`slice!` through the reader:

```ruby
class C
  attr_reader :name
  def initialize = @name = +"abc"
end
c = C.new
c.name.setbyte(0, 90)
p c.name
c.name.slice!(0)
p c.name
```

CRuby prints `"Zbc"`, `"bc"`. Spinel prints `"Zbc"`, `"Zbc"`.

A class that calls `setbyte` on the ivar itself, then `<<` through the reader:

```ruby
class C
  attr_reader :name
  def initialize = @name = +"abc"
  def poke = @name.setbyte(0, 90)
end
c = C.new
c.poke
c.name << "!"
p c.name
```

CRuby prints `"Zbc!"`. Spinel prints `"Zbc"`.

The String ivar only becomes a shared handle through the passes in `src/analyze.c`, and each one misses a case. `promote_shared_stored_strings` shares a reader alias (`x = c.name`) only when the ivar's own class mutates it, not when the only mutation is through the reader. The same function's pass for mutations through a reader only takes the mutators that have an ivar form (`SP_MUT_IVAR`), so `slice!` and `setbyte` through a reader are dropped (`[]=` and `insert` through a reader work since #5012). And `sb_mut_tabs_build` marks an ivar that its class mutates with `slice!` or `setbyte` as never to be shared, so any later mutation through its reader lands in a copy.
