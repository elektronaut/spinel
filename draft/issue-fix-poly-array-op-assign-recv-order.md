title: A global or ivar receiver is read after the call's arguments run, so an argument that reassigns it changes the result

When a call's receiver is a global, instance variable or class variable (`$a + [f]`, `@a.include?(x)`) and an argument calls a method that reassigns that variable, Spinel uses the new value as the receiver. Ruby evaluates the receiver before the arguments, so the old value should be used. It affects Array `+`, `union`, `|`, `-` and `include?`, String `+` and `==`, and Integer `+`, among others.

```ruby
def replace
  $a = [2]
  3
end
$a = [1]
p($a + [replace])
$a = [1]
p($a.union([replace]))
def rs
  $s = "z"
  "b"
end
$s = "a"
p($s + [rs].first)
```

CRuby prints `[1, 3]`, `[1, 3]`, `"ab"`. Spinel prints `[2, 3]`, `[2, 3]`, `"zb"`.

The same happens with an ivar receiver:

```ruby
class Box
  def initialize
    @a = [1]
  end

  def swap
    @a = [9]
    1
  end

  def run
    p(@a + [swap])
    @a = [1]
    p(@a.include?([swap].first))
  end
end
Box.new.run
```

CRuby prints `[1, 1]`, `true`. Spinel prints `[9, 1]`, `false`.

The builtin method arms that `emit_call` (`src/codegen_call.c`) dispatches to emit the receiver inline (`gv_a`) but hoist the arguments' setup code into a prelude that runs ahead of the whole statement, so the receiver variable is read after the argument's method call has already reassigned it.
