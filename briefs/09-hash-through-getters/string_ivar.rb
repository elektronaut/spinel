class C
  def initialize = @name = +"abc"
  def name = @name
end
c = C.new
c.name[0] = "X"
c.name << "!"
p c.name
