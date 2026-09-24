class C
  def c = (@c ||= {})
  def put_g(k, v) = c[k] = v
  def put_d(k, v) = @c[k] = v
end
o = C.new
o.put_g(1, 2)
o.put_d(:s, 3.5)
p o.c, o.c[1] + 1, o.c[:s]
