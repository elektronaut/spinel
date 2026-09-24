def r(a = {}, *rest, c) = [a, rest, c]
p r(5)
p r(1, 5)
def kk(a = {}, c, **kw) = [a, c, kw]
p kk(5)
