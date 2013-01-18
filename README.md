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
```
class Foo
  include LogMixin

  def do_something_harmless
    self.info("Doing something harmless...")
    # ...
  end

  def do_something_risky
    if self.on_fire?
      self.err("HELP!  I'm on fire!")
    else
      self.warn("Temperature is rising, but not on fire yet")
    end
    # ...
  end
end
```
