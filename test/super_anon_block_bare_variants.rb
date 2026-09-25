# super from a method with no proc of its own (an anonymous `&`, or one that
# yields) hands the block on to a parent that keeps it as `&handler`.
class Base
  def on(tag, &handler)
    @tag = tag
    @handler = handler
  end
  def fire(v) = @handler ? @handler.call(@tag, v) : "no handler for #{@tag}"
end

class Bare < Base
  def on(tag, &) = super
end
class Explicit < Base
  def on(tag, &) = super(tag, &)
end
class Implicit < Base
  def on(tag, &) = super(tag)
end
class Yielder < Base
  def on(tag)
    yield :setup, 0 if block_given?
    super
  end
end

ba = Bare.new
ba.on(:bare) { |t, v| "#{t}:#{v}" }
puts ba.fire(1)
ex = Explicit.new
ex.on(:explicit) { |t, v| "#{t}:#{v}" }
puts ex.fire(1)
im = Implicit.new
im.on(:implicit) { |t, v| "#{t}:#{v}" }
puts im.fire(1)
yi = Yielder.new
yi.on(:yielder) { |t, v| "#{t}:#{v}" }
puts yi.fire(1)

# no block at all: the parent sees nil
b = Bare.new
b.on(:none)
puts b.fire(2)

# a proc passed with & drives the splice
pr = proc { |t, v| "proc #{t}:#{v * 10}" }
e = Explicit.new
e.on(:p, &pr)
puts e.fire(3)
y = Yielder.new
y.on(:py, &pr)
puts y.fire(4)
