class Reg
  def initialize(&handler)
    @handler = handler
  end

  def poke(v) = @handler.call(v)
end

def install(&) = Reg.new(&)

install { |v| puts v }.poke(7)
