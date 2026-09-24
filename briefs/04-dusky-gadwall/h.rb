class Reg
  def initialize(x, &handler)
    @x = x
    @handler = handler
  end

  def poke(v) = @handler.call(v)
end

class Reg
  attr_writer :handler
end

class Bus
  def install(&handler)
    reg = Reg.new(1)
    reg.handler = handler
    @reg = reg
  end

  def poke(v) = @reg.poke(v)
end

class Box
  attr_accessor :code
end

class Computer
  attr_reader :bus

  def initialize
    @bus = Bus.new
  end

  def install(&) = bus.install(&)
  def poke(v) = bus.poke(v)
end

module M
  def self.run(bus)
    box = Box.new
    bus.install { |value| box.code = value }
    3.times { bus.poke(7) } until box.code
    box.code
  end
end

p M.run(Computer.new)
