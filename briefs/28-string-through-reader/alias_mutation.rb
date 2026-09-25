class C
  attr_reader :name
  def initialize = @name = +"ab"
end
c = C.new
x = c.name
c.name << "!"
p x
p c.name
