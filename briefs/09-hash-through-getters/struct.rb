S = Struct.new(:h)
s = S.new({})
s.h[1] = 2
s.h["x"] = "y"
p s.h
