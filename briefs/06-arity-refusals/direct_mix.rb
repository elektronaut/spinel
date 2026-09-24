def t
  yield
rescue ArgumentError
  "AE"
end
class Rest
  def m(x, *rest) = [x, rest.size]
  def run = [m(3), m(3, 4), m(1, k: 9), m(2, "s" * 2)]
end
p Rest.new.run
class Kw
  def m(x, k: 1) = [x, k]
  def run = t { m(3, 4) }
end
p Kw.new.run
p t { Kw.new.m(3, 4) }
def kwf(x, k: 1) = [x, k]
p t { kwf(3, 4) }
