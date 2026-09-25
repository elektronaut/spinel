# super inside a proc-form clone (the method reached through a poly
# dispatch) names the parent's method, not the clone's `m#pf`.
class P
  def m(x) = "P#{x}"
  def n(x) = "P.n#{x}"
end
class Q < P
  def m(x, &) = super
  def n(x, &) = super(x + 1)
end
class R < Q
  def m(x, &) = "R" + super
end
# a yielding override whose super goes to a plain parent
class Y < P
  def m(x) = block_given? ? yield(x) : super
end
[P, Q, R, Y].each { |k| p k.new.m(1) }
[Q, R].each { |k| p k.new.n(1) }
[Y, Q].each { |k| p k.new.m(2) { |v| "blk#{v}" } }
