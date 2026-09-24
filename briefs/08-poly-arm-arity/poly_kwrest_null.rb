class A
  def m(x) = x
end
class B < A
  def m(x, **kw) = [x, kw.size]
end
[A.new, B.new].each { |o| p o.m(3) }
