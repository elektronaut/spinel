class Base
  def on(&handler) = @handler = handler
  def fire(value) = @handler.call(value)
end
class A < Base
  def on(&) = super(&)
end
class B < Base
  def on(&) = super(&)
end
[A, B].each do |k|
  o = k.new
  o.on { |v| p [k.name, v] }
  o.fire(1)
end
