title: `String#[]=` through a reader raises NoMethodError, and `insert` through a reader is dropped

A class holds a mutable String in an ivar and exposes it through a reader (`def name = @name` or `attr_reader`). Index assignment through the reader (`c.name[0] = "X"`) raises NoMethodError at run time, although `<<` through the same reader works.

```ruby
class C
  def initialize = @name = +"abc"
  def name = @name
end
c = C.new
c.name[0] = "X"
c.name << "!"
p c.name
```

CRuby prints `"Xbc!"`. Spinel raises `undefined method '[]=' for an instance of String (NoMethodError)`.

`String#insert` through a reader compiles but leaves the ivar unchanged:

```ruby
class W
  attr_reader :s
  def initialize = @s = +"abc"
end
w = W.new
w.s.insert(0, ">")
p w.s
```

CRuby prints `">abc"`. Spinel prints `"abc"`.

`[]=` and `insert` are left out of the `SP_MUT_IVAR` mutators in `sp_str_mutator` (`src/analyze_util.c`), so a reader whose result they mutate never hands out the ivar's shared string handle, and none of the String `[]=`/`insert` codegen arms accept a reader call as the receiver, only a local or an ivar read.
