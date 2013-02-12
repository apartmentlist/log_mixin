LogMixin
===

The LogMixin module provides (you guessed it) a mixin to make logging more
convenient.  It is intended to work both with and without Rails, to silence
logging in tests by default but provide access to it when explicitly
requested, to log to stderr (or Rails.logger) by default but accept other
logging targets, and other conveniences.

Released under the three-clause BSD open source license.
http://opensource.org/licenses/BSD-3-Clause

Usage
===
```ruby
class Foo
  include LogMixin

  def do_something_harmless
    self.debug("Arcane internal debugging parameters: foo=#{foo} bar=#{bar}")
    self.info("Doing something harmless...")
    # ...
  end

  def do_something_risky
    if self.on_fire?
      self.err("Ignition initiated")
      self.fatal("HELP!  I'm on fire!") if on_fire
    else
      self.warn("Temperature is rising, but not on fire yet")
    end
    # ...
  end
end
```

Logging and Tests
===
By default, log messages are silenced during tests.  This is usually what
you want.

Sometimes you may want to test logging behavior.  It's usually not advisable
to test the *content* of log messages.  If you know what you're signing up
for, you might test that an INFO message was logged rather than a WARNING,
however.  Be careful -- you're creating an implicit contract.  That having
been said, here is how you can test log messages in RSpec:
```ruby
it 'should log correctly' do
  obj = MyClass.new
  obj.__handle.msgs.should have(0).messages
  obj.do_something_that_logs_twice
  obj.__handle.msgs.should have(2).messages
  obj.do_something_that_logs_an_error
  obj.__handle.msgs.select {|msg| msg =~ /ERROR/}.should have(1).message
end
```

What if you're running your tests and you have a bug, but you can't figure
out what's going on, so you actually _want_ to see the log messages?  Well,
you can.  Here is how you activate logging during tests, which you should
presumably only do temporarily:
```ruby
  ['TESTING', 'RAILS'].each do |c|
    LogMixin.send(:remove_const, c)
    LogMixin.const_set(c, false)
  end
```

LogMixin supports both inclusion (i.e., instances of the class get the
logging methods) and extension (i.e., the class or module itself get the
logging methods).
```ruby
class ChattyInstance
  include LogMixin
  ...
end

module ChattyModule
  extend LogMixin
  ...
end

c = ChattyInstance.new
c.info("I'm an instance!")
ChattyModule.info("I'm a module!")
LogMixin.info("You can even log with LogMixin itself...")
LogMixin.warn("...but 'mixin' is a bit of a misnomer in that case.")
```

Want to change the log message format?  You have lots of flexibility.  See
the documentation for ```#configure_logs``` and ```VBLM_DEFAULT_FORMAT```.

