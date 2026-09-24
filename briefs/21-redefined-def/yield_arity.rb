def y1(x) = yield(x)
begin
  y1 { |v| p v }
rescue ArgumentError => e
  p e.message
end
def y(x, k: 1) = yield(x + k)
begin
  y(1, 2) { |v| p v }
rescue ArgumentError => e
  p e.message
end
