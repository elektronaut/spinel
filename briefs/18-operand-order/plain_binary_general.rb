def replace
  $a = [2]
  3
end
$a = [1]
p($a + [replace])
$a = [1]
p($a.union([replace]))
$a = [1]
p($a.include?([replace].first))
$a = [1]
b = $a | [replace]
p b
$a = [1]
p [$a, [replace]]
def rs
  $s = "z"
  "b"
end
$s = "a"
p($s + [rs].first)
