def f__redef1 = "own"

# an alias of a redefined top-level method names the definition in effect
# where the alias runs
def f = 1
alias saved f
def f = 2
p saved
p f

def g(x) = x + 1
alias g_one g
p g_one(1)
def g(x) = x * 10
alias g_two g
def g(x) = x - 1
p g_one(2)
p g_two(3)
p g(4)

# the private name of an earlier definition does not collide with a method
# the program defines itself (f is the first redefined name)
p f__redef1
def h = :first
p h
def h = :second
p h
