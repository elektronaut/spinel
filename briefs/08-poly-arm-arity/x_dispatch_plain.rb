class A
  def h(a = {}, c) = [:A, a, c]
end
class B
  def h(a = {}, c) = [:B, a, c]
end
[A.new, B.new].each { |o| p o.h(5) }
[A.new, B.new].each { |o| p o.h(1, 5) }
