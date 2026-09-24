class Grand
  attr_accessor :x
end
class Parent < Grand
  def x=(v)
    @x = v * 10
  end
end
class Mid < Parent
  attr_writer :x
end
class Leaf < Mid
  def x=(v)
    super
  end
end
l = Leaf.new
l.x = 3
p l.x
