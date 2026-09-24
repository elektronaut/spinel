class A
  def initialize(x) = @x = x
  def to_s = "A(#{@x})"
end
class B
  def initialize(x) = @x = x
  def to_s = "B(#{@x})"
end
A.new(1)
B.new(2)
def pick(i) = i == 0 ? A : B
def build(i) = pick(i).new(5)
puts build(0)
puts build(1)
v = build(0)
puts "#{v}"
puts v.to_s
