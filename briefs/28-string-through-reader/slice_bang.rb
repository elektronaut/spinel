class C
  attr_reader :name
  def initialize = @name = +"abc"
end
c = C.new
c.name.setbyte(0, 90)
p c.name
c.name.slice!(0)
p c.name
