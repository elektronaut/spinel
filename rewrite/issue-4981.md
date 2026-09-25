When a class overrides an inherited `attr_accessor` with its own `def x=` (or `def x`), Spinel still treats every class below it as holding the attribute. A subclass further down that re-declares the attribute with `attr_writer :x` and is then reached through `super` from its own subclass runs the overriding `def` instead of the re-declared writer. This is a case left over from #4909.

```ruby
class Grand
  attr_accessor :x
end
class Parent < Grand
  def x=(v)
    @x = v * 10
  end
end
class Mid < Parent
  attr_writer :x
end
class Leaf < Mid
  def x=(v)
    super
  end
end
l = Leaf.new
l.x = 3
p l.x
```

CRuby prints `3`. Spinel prints `30`.

The same thing breaks a plain call without `super`: a subclass that just inherits from the class with the `def` reads and writes the attribute directly and skips the def.

```ruby
class Grand
  attr_accessor :x
end
class Parent < Grand
  def x=(v)
    @x = v * 10
  end
  def x = @x + 1
end
class Child < Parent
end
c = Child.new
c.x = 3
p c.x
```

CRuby prints `31`. Spinel prints `3`.

`inherit_members` in `src/analyze_scope.c` copies a parent's reader and writer flags into every subclass, including one that defines the method itself with `def`, so the flag keeps going down the chain past the def. A class below the def then looks like it has the attribute, and `super_lands_on_attr` (from #4909) sees `Parent` holding the same flag as `Mid`. It concludes that `Mid` only inherited the writer and walks past it to `Parent`'s def.
