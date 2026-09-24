class C
  def initialize = @c = {}
  def put(k, v) = @c[k] = v
  def cache = @c
end
c = C.new; c.put(1, 2); x = c.cache; x["x"] = "y"; p c.cache
