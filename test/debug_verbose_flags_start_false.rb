# $DEBUG and $VERBOSE start false, and keep whatever the program assigns.
p $DEBUG, $VERBOSE
puts "debugging" if $DEBUG
puts "quiet" unless $VERBOSE
p $VERBOSE.nil?, $DEBUG == false
def quietly
  old = $VERBOSE
  $VERBOSE = nil
  r = yield
  $VERBOSE = old
  r
end
p quietly { $VERBOSE }
p $VERBOSE
def flags = [$DEBUG, $VERBOSE]
p flags
$DEBUG ||= :on
p $DEBUG
