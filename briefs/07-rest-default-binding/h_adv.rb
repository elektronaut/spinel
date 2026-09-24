def r(*xs) = xs.inspect
def g(x) = x + 1
def h(a, b = :d) = "#{a.inspect},#{b.inspect}"
puts r(*nil)
puts r(*5)
puts r(1, *5)
puts g(3)
puts g(*5)
puts h(*:s)
puts h(*2.5)
puts h(*"q")
puts h(*true)
begin
  h(*nil)
rescue ArgumentError => e
  puts "AE #{e.message}"
end
class O
  def m(a, b = 0) = "m(#{a},#{b})"
end
puts O.new.m(*7)
