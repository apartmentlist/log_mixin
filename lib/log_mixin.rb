# Mix-in class to support logging under Heroku, local Rails, command line,
# test environment, etc.  Especially useful for utilities which might not
# be run under Rails, so Rails.logger isn't an option.
#
# Usage:
#    class MyClass
#       include LogMixin
#       # if you write an initializer, invoke configure_logs there -- see below
#       ...
#    end
#
#    obj = MyClass.new
#    obj.info("Something happened!")   # default severity is INFO
#    obj.fatal("EMERGENCY!", level: :critical)
#
# Testing the contents of log messages is suspicious, but you may want to
# test that logging occurred, and in any case, we won't stop you from testing
# what you want.  Here's how you access the logging from a test:
#
#    it 'should log correctly' do
#      obj = MyClass.new
#      obj.__handle.msgs.should have(0).messages
#      obj.do_something_that_logs_twice
#      obj.__handle.msgs.should have(2).messages
#      obj.do_something_that_logs_an_error
#      obj.__handle.msgs.select {|msg| msg =~ /ERROR/}.should have(1).message
#    end
#
# Want to hack your tests so that you temporarily output log messages?
#      ['TESTING', 'RAILS'].each do |c|
#        LogMixin.send(:remove_const, c)
#        LogMixin.const_set(c, false)
#      end
#

require 'time'   # for time-stamping log messages

module LogMixin

  class Error < StandardError; end
  class InitError < Error; end

  # If your class has its own initializer, you probably want to invoke
  # configure_logs in that initializer.  If you don't write an initializer
  # and use the default, this should suffice.
  def initialize(*args)
    super(*args)
    configure_logs   # with no other info, configure with default params
  end

  ############################## FOR TEST ONLY ##############################

  # Special-case the condition of running under a test environment
  # We probably don't want to spew logging output when running unit tests
  TESTING = Object.constants.include?(:RSpec)

  # FakeFileHandle is a place to send test logging output
  class FakeFileHandle
    attr_reader :msgs
    def initialize; @msgs = []; end
    def print(msg); @msgs << msg; end
  end

  ############################## END TEST ONLY ##############################

  # If we're running under Rails, then we'll probably want to use the Rails
  # logging facilities.  (TODO: Add a good Rails auto-detector.)
  # Until we build in a Rails auto-detector, callers can use this ugly hack:
  #    LogMixin.send(:remove_const, "RAILS")
  #    LogMixin.const_set("RAILS", true)
  RAILS = false

  # Log levels: 0 = CRITICAL, 1 = ERROR, 2 = WARNING, 3 = INFO, 4 = DEBUG
  # Any other integer is also valid, but doesn't map to a named level.
  # An *object's* log level is its threshold for caring about log messages.
  # A *message's* log level is its importance.
  #

  VBLM_LOG_LEVEL_NAMES = {
    :critical => 0,
    :error    => 1,
    :warning  => 2,
    :info     => 3,
    :debug    => 4,
  }
  VBLM_DEFAULT_LOG_LEVEL = :info

  # Default format looks like this:
  # "[2012-04-18 12:00:00] MyObject: ERROR: Something went wrong"
  # Note timestamp, caller, severity, message
  #
  # When creating custom formats, :caller can be either a fixed string (such as
  #   the program name or '') or a function on the calling object (as below).
  # :severity can be a fixed string (usually '') or a function on the
  #   integer log_level.
  # :timestamp must be a string, and may include any format chars understood by
  #   Time.strftime
  VBLM_DEFAULT_FORMAT = {
      :timestamp => '[%Y-%m-%d %H:%M:%S] ',
      :caller => lambda { |obj| obj.class.name + ": " },
      :severity => lambda { |level|
         level = self.log_level_int(level)
         ((level >= 0 and level <= 4) ?
          %W{CRITICAL ERROR WARNING INFO DEBUG}[level] :
          "Log level #{level.to_s}") + ": " },
  }


  # We want to handle "log_level = 3" and "log_level = :info" with equal grace.
  # This function canonicalizes its input to an integer (e.g. :info becomes 3)
  def self.log_level_int(symbol_or_int)
    if symbol_or_int.class == Symbol && VBLM_LOG_LEVEL_NAMES.key?(symbol_or_int)
      return VBLM_LOG_LEVEL_NAMES[symbol_or_int]
    end
    if symbol_or_int.class == Fixnum
      return symbol_or_int
    end
    raise ArgumentError, "Invalid log level: #{symbol_or_int.to_s}"
  end

  # Any object using the LogMixin module must call configure_logs() before
  # starting to log.
  #  * :log_handles is a list of objects which respond to "print"
  #  * :log_level is the maximum (lowest-priority) level that this object cares
  #      about logging -- log messages of higher log_level (lower priority)
  #      will be ignored
  #  * :format is a hash with any or all of [:timestamp, :caller, :severity]
  #    * keys which are nil or not overridden will retain default values
  #    * for details of hash values, see VBLM_DEFAULT_FORMAT above
  #
  def configure_logs(options={})
    default_options = {
      :log_handles => [$stdout],
      :log_level   => VBLM_DEFAULT_LOG_LEVEL,
      :format      => VBLM_DEFAULT_FORMAT,
      :test_logging_internals => false,
    }
    opts = default_options
    opts.update(options)
    # Are we testing?  If so, don't output logs, just keep them in memory.
    # (Unless we're testing the internals of the logging module.)
    if TESTING and not opts[:test_logging_internals] then
      @__handle = FakeFileHandle.new
      @vblm_log_handles = [@__handle]
    else
      @vblm_log_handles = opts[:log_handles] || []
    end
    @vblm_log_level = opts[:log_level]
    @vblm_format = opts[:format] || VBLM_DEFAULT_FORMAT
    # Caller can request e.g. custom timestamp, keeping other default formatting
    [:timestamp, :caller, :severity].each do |key|
      @vblm_format[key] ||= VBLM_DEFAULT_FORMAT[key]
    end
    @__log_mixin_initialized = true
  end

  # For changing log level of a running process, e.g. via HTTP
  def setLogLevel(log_level)
    @vblm_log_level = log_level
  end

  # Handle parameters (formatting options, in our case) which may either be
  # fixed strings or functions returning strings.  If the input is a function,
  # call it with the given *args and return its result.
  #
  def stringOrFunctionOutput(s_or_f, *args)
    s_or_f.respond_to?('call') ?  s_or_f.call(*args) : s_or_f.to_s
  end

  # Return the message formatted according to this LogMixin object's params
  # (Usually this means prepending a timestamp, caller, and severity, and
  # adding a newline.)
  #
  def formattedMessage(msg, options={})
    default_options = { :log_level => VBLM_DEFAULT_LOG_LEVEL }
    opts = default_options
    opts.update(options)
    timestamp = Time.now.strftime(@vblm_format[:timestamp])
    # :caller and :severity may be fixed strings, or functions returning strings
    caller = stringOrFunctionOutput(@vblm_format[:caller], self)
    severity = stringOrFunctionOutput(@vblm_format[:severity], opts[:log_level])
    "#{timestamp}#{caller}#{severity}#{msg}\n"
  end

  # Use Rails.logger to do the logging
  # This assumes that the caller has detected a Rails environment.
  #
  def __railsLog(msg, level)
    # First, squash log levels worse than CRITICAL to CRITICAL, and levels
    # more benign than DEBUG to DEBUG.
    rails_level = level
    if rails_level < LogMixin::log_level_int(:critical) then
      rails_level = LogMixin::log_level_int(:critical)
    elsif rails_level > LogMixin::log_level_int(:debug) then
      rails_level = LogMixin::log_level_int(:debug)
    end
    case rails_level
      when LogMixin::log_level_int(:debug)    then Rails.logger.debug(msg)
      when LogMixin::log_level_int(:info)     then Rails.logger.info(msg)
      when LogMixin::log_level_int(:warning)  then Rails.logger.warn(msg)
      when LogMixin::log_level_int(:error)    then Rails.logger.error(msg)
      when LogMixin::log_level_int(:critical) then Rails.logger.fatal(msg)
    end
  end
  # Print the message to "all" logging handles, if the message level is of
  # sufficient priority that this object cares about it (i.e. if the numeric
  # message log level is <= the object log level).  Silently discard the
  # message if its priority is insufficient.
  #
  # "All" filehandles include everything in @vblm_log_handles, except that
  # if we are running under Rails, the default handle $stdout is ignored
  # and replaced with the Rails logger.
  #
  def log(msg, options={})
    if not @__log_mixin_initialized
      raise InitError, "#{self.class} object uses LogMixin " +
        "but never called configure_logs"
    end
    default_options = {:level => VBLM_DEFAULT_LOG_LEVEL}
    opts = default_options
    opts.update(options)

    level = LogMixin::log_level_int(opts[:level])
    return if level > LogMixin::log_level_int(@vblm_log_level)

    # Write the log message, in the appropriate style
    formatted_msg = self.formattedMessage(msg, :log_level => level)
    if RAILS then
      # log Rails-style, with Rails.logger.{debug,info,warn,error,fatal}
      __railsLog(msg, level)
    else
      # format message, and print to $stdout (unless $stdout isn't requested)
      $stdout.print(formatted_msg) if @vblm_log_handles.include?($stdout)
    end

    # Print to the provided file handles (except stdout, which we've covered)
    @vblm_log_handles.reject {|h| h == $stdout}.each do |handle|
      # Support lazy-evaluation of log handles, so that loggable objects can
      # be instantiated without creating log files until they actually
      # log something.
      if handle.respond_to?(:call) then
        @vblm_log_handles[@vblm_log_handles.index(handle)] = handle.call
        handle = handle.call
      end

      handle.print(formatted_msg)
    end
  end

  def debug(msg, options={}); log(msg, options.merge(level: :debug   )); end
  def  info(msg, options={}); log(msg, options.merge(level: :info    )); end
  def  warn(msg, options={}); log(msg, options.merge(level: :warning )); end
  def   err(msg, options={}); log(msg, options.merge(level: :error   )); end
  def fatal(msg, options={}); log(msg, options.merge(level: :critical)); end

end  # module LogMixin
