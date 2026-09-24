class A
  def h(a = {}, c) = [:A, a, c]
end
class B
  def h(a = {}, c) = [:B, a, c]
end
[A.new, B.new].each do |o|
  begin
    p o.h
  rescue ArgumentError => e
    p e.message
  end
end
