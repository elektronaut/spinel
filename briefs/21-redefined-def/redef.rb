def tw(&b) = [:first]
def tw(a)
  a.each { |x| yield x }
  [:second]
end
p tw([1]) { |x| x }
