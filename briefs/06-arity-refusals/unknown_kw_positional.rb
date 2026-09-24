def g2(x, y = 7, k: 1) = [x, y, k]
p((g2(1, j: 2) rescue :argument_error))
