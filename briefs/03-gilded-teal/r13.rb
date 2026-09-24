class Register
  def initialize(&handler)
    @handler = handler
  end

  def poke(value) = @handler.call(value)
end

class Bus
  def install(&)
    @register = Register.new(&)
  end

  def poke(value) = @register.poke(value)
end

bus = Bus.new
bus.install { |value| puts value }
bus.poke(7)
