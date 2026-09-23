# A class variable's slot is a GC root: an Array, a String, a Hash, an
# object or a poly value held only in `@@x` survives allocation pressure
# and reads back unchanged (#4864).

class Box
  attr_reader :v
  def initialize(v) = @v = v
end

class C
  @@a = [0]
  @@s = "s"
  @@h = {}
  @@b = Box.new(0)
  @@p = 1

  def fill(n)
    @@a = (1..n).to_a
    @@s = "str" * n
    @@h = { n => [n, n] }
    @@b = Box.new([n] * 2)
    @@p = n.to_s + "!"
    @@a |= [n + 1]
    nil
  end

  def self.p_int = @@p = 7

  def read = [@@a, @@s, @@h, @@b.v, @@p]
end

c = C.new
c.fill(3)
junk = (1..2000).map { |i| [i, i.to_s, { i => i }] }
p junk.size
p c.read
C.p_int
c.fill(4)
junk = (1..2000).map { |i| [i.to_s * 2] }
p junk.size
p c.read
