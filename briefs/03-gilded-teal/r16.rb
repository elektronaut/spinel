class Register
  def initialize(base, &handler)
    @base = base
    @handler = handler
  end

  def poke(value) = @handler.call(value)
end

class Bus
  def install(&handler)
    @register = Register.new(1) { |value| handler.call(value) }
  end

  def poke(value) = @register.poke(value)
end

bus = Bus.new
bus.install { |value| puts value }
bus.poke(7)
