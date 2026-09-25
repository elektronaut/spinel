class A
  def w(x) = yield(x)
end
class B
  def w = yield(:b)
end
class C
  def w(x, y) = yield(x, y)
end
[A.new, B.new, C.new].each do |o|
  p o.w { |v| [:blk, v] }
rescue ArgumentError => e
  p e.message
end
