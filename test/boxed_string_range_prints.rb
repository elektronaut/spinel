# A String range carried boxed -- an element of a mixed array, one argument of
# a several-argument p -- inspects and prints as the range, not as an object.

x = [("a".."c"), 1]
p x
puts x.inspect
p ("a"..."c"), 2
puts x[0]
puts "#{x[0]}!"
h = {k: ("x".."z"), n: 1}
p h
print x[0], "\n"
