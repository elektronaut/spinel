class Base
  def initialize = @c = {}
  def cache = @c
  def put(k, v) = @c[k] = v
end
class Sub < Base
  def cache = super
end
s = Sub.new
s.put(1, 2)
s.cache["x"] = "y"
p s.cache
