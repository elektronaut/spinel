# A bare call to a subclass's attr_reader that overrides an inherited def
# answers the reader's ivar, typed as the ivar, not as the def's return.
class Terminal
  def seek_to = 0.0
  def label = "none"
end

class Window < Terminal
  attr_reader :seek_to, :label

  def initialize(length)
    @seek_to = 0.0
    @length = length
    @label = nil
  end

  def click(left)
    @seek_to = (left / 80.0) * @length
    @label = left > 10 ? :far : "near"
  end

  def follow = [seek_to]
  def last = seek_to
  def name = label
  def pick(action) = { seek: seek_to, back: 1.0 }.fetch(action)
end

# A subclass def over an inherited reader still answers the def.
class Base
  attr_reader :count

  def initialize = @count = 3
end

class Doubled < Base
  def count = "twice"
  def show = count
end

w = Window.new(ARGV.empty? ? 100 : "x")
w.click(40)
p w.follow
p w.last
p w.name
p w.pick(:seek)
p w.pick(:back)
p Doubled.new.show
p Base.new.count
