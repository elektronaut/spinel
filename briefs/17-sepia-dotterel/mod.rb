class Mem
  def initialize
    @cells = Array.new(4, 0)
  end

  def poke(addr, value)
    @cells[addr] = value
  end

  def []=(addr, value)
    poke(addr, value)
  end

  def [](addr) = @cells[addr]
end

module Traps
  def install_trap(addr, &handler)
    (@traps ||= {})[addr] = handler
  end

  private

  def run_traps
    @traps[@pc]&.call if @traps
  end
end

class Cpu
  include Traps

  def initialize
    @pc = 3
    @traps = nil
  end

  def step = run_traps
end

mem = Mem.new
mem.poke(1, 7)
cpu = Cpu.new
cpu.install_trap(3) { 42 }
p mem[1], cpu.step
