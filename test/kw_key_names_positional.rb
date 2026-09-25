# A key binds only a keyword parameter: a positional parameter sharing its
# name is still short (arity error first) and the key is unknown. The arity
# message names the required keywords, and a missing keyword is reported
# before an unknown one.
def t
  yield
rescue ArgumentError => e
  e.message
end

def f(x, k: 1) = [x, k]
p t { f(x: 2) }
p t { f(1, x: 2) }
p t { f(1, k: 3, x: 2) }
p f(1, k: 3)

def req_kw(x, k:) = [x, k]
p t { req_kw(k: 2) }
p t { req_kw(x: 1, k: 2) }
p t { req_kw(1, x: 1, k: 2) }
p req_kw(1, k: 2)

def g(x, y = 5, k: 1) = [x, y, k]
p t { g(y: 1) }
p t { g(1, y: 1) }

class C
  def m(x, k: 1) = [x, k]
  def run = [t { m(x: 2) }, t { m(1, x: 2) }]
end
p C.new.run
p t { C.new.m(x: 2) }
p t { C.new.m(1, x: 2) }

def g2(x, k:) = x
p t { g2(1, 2, k: 3) }
def h(x, k:, **o) = [x, o.size]
p t { h(k: 3) }
p h(1, k: 3, z: 4)
def only_kw(k:, a: 1) = k
p t { only_kw(j: 1) }
p t { only_kw(k: 1, j: 1) }
