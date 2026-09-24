class A
  def initialize(x) = @x = x
  def to_s = "A(#{@x})"
end
class C
  def self.new(x) = "C.new(#{x})"
end
def pick(i) = i == 0 ? A : C
def build(i, *args) = pick(i).new(*args)
def one(i, v) = pick(i).new(v)
puts build(0, 5)
puts one(1, 6)
puts build(1, 7)
