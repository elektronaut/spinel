class A
  def m(x, y = 2) = x * y
end
class B < A
  def m(x) = x + 1
end
[A.new, B.new].each do |o|
  begin
    p o.m(3, 4)
  rescue ArgumentError
    p :argument_error
  end
end
