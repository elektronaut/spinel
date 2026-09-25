class Base
  def on(tag, &handler) = @handler = handler
  def fire(v) = @handler.call(v)
end
class A < Base
  def on(tag, &) = super
end
a = A.new
a.on(:x) { |v| p v }
a.fire(3)
