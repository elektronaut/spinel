status: claimed
branch: fix-class-value-new-arms

# class-value-new

Class-value `k.new(...)` dispatch gaps.

## sleety-gadwall

boxed receiver never gets a Struct arm for positional args: `{0=>S}.fetch(0).new(5)` raises NoMethodError  (also a Struct with its own initialize, positional k.new(v))

- `11-class-value-new/f2_struct_custom_init.rb` (CRuby 4.0 output in `f2_struct_custom_init.rb.expected`)

## wan-merganser

Class-value `k.new(...)` never dispatches to a user `self.new`: a `self.new` returning another type fails in C; one calling `super` raises "super: no superclass method 'new'" (master, with or without splat)

- `11-class-value-new/f5_custom_selfnew.rb` (CRuby 4.0 output in `f5_custom_selfnew.rb.expected`)
- `11-class-value-new/f5b_selfnew_with_init.rb` (CRuby 4.0 output in `f5b_selfnew_with_init.rb.expected`)

