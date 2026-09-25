# recursion in an earlier definition reaches that definition while it is
# the one in effect
def count(n) = n == 0 ? 0 : 1 + count(n - 1)
p count(3)
def count(n) = 100
p count(3)

def fact(n)
  return 1 if n <= 1
  [n].map { |k| k * fact(k - 1) }.first
end
p fact(5)
def fact(n) = -1
p fact(5)

# an alias that runs after the redefinition: the old body's calls reach
# the new definition
def walk(n) = n == 0 ? [:old] : walk(n - 1) + [:old]
alias walk_old walk
def walk(n) = [:new, n]
p walk_old(2)
p walk(2)
