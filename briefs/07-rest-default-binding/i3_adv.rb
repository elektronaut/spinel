def try
  puts yield
rescue ArgumentError => e
  puts "AE #{e.message}"
end
def c3(a, b = 0, c = 0) = "c3(#{a.inspect},#{b.inspect},#{c.inspect})"
def kw(a, b = 0, k: 1) = "kw(#{a.inspect},#{b.inspect},#{k})"
def two(a, b) = "two(#{a},#{b})"
ints = [1]
try { c3(*ints, "s") }
try { c3(*ints, "s", [2]) }
try { c3(*[], 7) }
try { c3(*[1, 2], "x") }
try { c3(*[1, 2, 3], "x") }
try { kw(*[1], 2, k: 3) }
try { kw(*[], 2, k: 3) }
try { c3(9, *[], 8) }
try { c3(9, *[1], 8) }
try { c3(9, *[1, 2], 8) }
class O
  def m(a, b) = "m(#{a},#{b})"
  def o(a, b = 0, c = 0) = "o(#{a},#{b},#{c})"
end
try { O.new.m(*[1, 2], 3) }
try { O.new.o(*[1], 3) }
arr = []
5.times { |i| arr << c3(*[i], "s#{i}" * 3) }
puts arr.inspect
