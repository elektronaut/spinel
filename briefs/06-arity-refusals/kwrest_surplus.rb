class B
  def m(x, **kw) = [x, kw.size]
end
def f(x, **kw) = [x, kw.size]
p((B.new.m(3, 4) rescue :argument_error))
p((f(3, 4) rescue :argument_error))
