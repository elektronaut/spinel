class Register
  def initialize
    @handler = nil
  end

  def handle(&handler)
    @handler = handler
  end

  def poke(value) = @handler.call(value)
end

class Bus
  attr_reader :register

  def initialize
    @register = Register.new
  end

  def install(&) = @register.handle(&)
end

class Recorder
  attr_reader :code

  def initialize(bus)
    @code = 0
    bus.install { |value| @code = value }
  end
end

bus = Bus.new
recorder = Recorder.new(bus)
bus.register.poke(7)
puts recorder.code
