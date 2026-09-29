class Box
  def initialize = @v = 1
  def v2(x) = @v + x
end

class C
  def c = (@c ||= {})
  def a = (@a ||= [])
  def put_d(k, v) = @c[k] = v
  def put_s(k, v)
    @c[k] = v
    nil
  end
  def get_d(k) = @c[k]
  def a_set(i, v) = @a[i] = v
  def a_get(i) = @a[i]
  def a_push(v) = @a << v
  def a_size = @a.size
  def h_size = @c.size
  def s_app(x) = @s << x
  def each_k = @c.each { |k, _| p k }
  def each_s
    @c.each { |k, _| p k }
    nil
  end
  def map_a = @a.map { |x| x + 1 }
  def fetch_x = @c.fetch("x", 0)
  def pv = @b.v2(1)
  def self.cput(k, v) = @ch[k] = v
  def cond_init(f)
    @h = {} if f
    @h[:z] = 1
    @h
  end
  def fill
    @s = +"s"
    @b = Box.new
  end
end

def t
  yield
rescue NoMethodError => e
  puts e.message
end

o = C.new
t { o.put_d("x", "y") }
t { o.put_s("x", "y") }
t { p o.get_d("x") }
t { o.a_set(0, 1) }
t { p o.a_get(0) }
t { o.a_push(1) }
t { p o.a_size }
t { p o.h_size }
t { o.s_app("z") }
t { o.each_k }
t { o.each_s }
t { p o.map_a }
t { p o.fetch_x }
t { p o.pv }
t { C.cput(:x, 1) }
t { p C.new.cond_init(false) }
p C.new.cond_init(true)
o.c["x"] = 2
o.a << 3
o.fill
p o.put_d("y", 3), o.get_d("x"), o.a_size, o.h_size, o.map_a, o.fetch_x, o.pv
p o.s_app("q")
o.each_k
o.each_s
