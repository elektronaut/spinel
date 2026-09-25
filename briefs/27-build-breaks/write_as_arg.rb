def show(s) = s.length
buf = nil
n = show(buf = +"abc")
3.times { buf << "d" }
p [n, buf]
