class A
  def initialize(x) = @x = x
  def to_s = "A(#{@x})"
end
class C
  def self.new(x) = super(x * 10)
  def initialize(x) = @x = x
  def to_s = "C(#{@x})"
end
def pick(i) = i == 0 ? A : C
def build(i, *args) = pick(i).new(*args)
def one(i, v) = pick(i).new(v)

puts build(1, 7)
