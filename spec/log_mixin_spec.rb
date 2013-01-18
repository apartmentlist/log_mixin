require 'log_mixin'

RSpec.configure { |config| config.mock_with :rr }

describe LogMixin do
  before :all do
    FIXED_TIME = Time.new(2012,2,29,9,0,0)
    class Dummy
      include LogMixin
      # Grant access to internals for LogMixin module test purposes.
      # FOR TEST ONLY!  Not a public interface!  Don't try this at home, kids!
      attr_reader :vblm_log_handles, :vblm_log_level, :vblm_format, :__handle
    end
  end

  before :each do
    stub(Time).now { FIXED_TIME }
  end

  describe '.configure_logs' do
    it 'should set instance vars with default params' do
      obj = Dummy.new
      obj.configure_logs()

      obj.vblm_log_handles.should == [obj.__handle]
      obj.vblm_log_level.should == LogMixin::VBLM_DEFAULT_LOG_LEVEL
      obj.vblm_format.should have(3).keys

      format_hash = LogMixin::VBLM_DEFAULT_FORMAT
      [:timestamp, :caller, :severity].each do |key|
        obj.vblm_format.key?(key).should be_true
        obj.vblm_format[key].should == format_hash[key]
      end
    end

    it 'should set instance vars with custom params' do
      obj = Dummy.new
      format_hash = {
        :timestamp => '%d@%H:%M:%S',
        :caller => 'my_prog_name',
        :severity => lambda { 'LOG: ' },
      }
      obj.configure_logs(:log_handles=>[], :log_level=>2, :format=>format_hash,
                        :test_logging_internals => true)

      obj.vblm_log_handles.should == []
      obj.vblm_log_level.should == 2
      obj.vblm_format.should have(3).keys

      [:timestamp, :caller, :severity].each do |key|
        obj.vblm_format.key?(key).should be_true
        obj.vblm_format[key].should == format_hash[key]
      end
    end

    it 'should set instance vars correctly with empty params' do
      obj = Dummy.new
      obj.configure_logs(:log_handles=>[], :log_level=>2, :format=>{},
                        :test_logging_internals => true)

      obj.vblm_log_handles.should == []
      obj.vblm_log_level.should == 2
      obj.vblm_format.should have(3).keys

      format_hash = LogMixin::VBLM_DEFAULT_FORMAT
      [:timestamp, :caller, :severity].each do |key|
        obj.vblm_format.key?(key).should be_true
        obj.vblm_format[key].should == format_hash[key]
      end
    end

    it 'should not override format with hash values of nil' do
      obj = Dummy.new
      empty_format = {:timestamp => '', :caller => '', :severity => ''}
      obj.configure_logs(:format => empty_format)

      obj.vblm_log_handles.should == [obj.__handle]
      obj.vblm_log_level.should == :info
      obj.vblm_format.should have(3).keys

      format_hash = empty_format
      [:timestamp, :caller, :severity].each do |key|
        obj.vblm_format.key?(key).should be_true
        obj.vblm_format[key].should == format_hash[key]
      end
    end
  end

  describe '.formattedMessage' do
    context 'format options are all defaults' do
      it 'should format correctly' do
        obj = Dummy.new
        obj.configure_logs()
        msg = "Hello, world!"
        formatted_msg = obj.formattedMessage(msg)
        formatted_msg.should include(msg)
        formatted_msg.should include(FIXED_TIME.strftime('[%Y-%m-%d %H:%M:%S]'))
        formatted_msg.should include('Dummy: ')
        formatted_msg.should include('INFO: ')
      end
    end
    context 'format options are set to empty' do
      it 'should format correctly' do
        obj = Dummy.new
        format_hash = {:timestamp => '', :caller => '', :severity => ''}
        obj.configure_logs(:format=>format_hash)
        msg = "Hello, world!"
        formatted_msg = obj.formattedMessage(msg)
        formatted_msg.should == msg + "\n"
      end
    end
    context 'format options are partially set, partially nil' do
      it 'should format correctly' do
        obj = Dummy.new
        format_hash = {:timestamp => '[%H:%M] ', :caller => 'PROG: '}
        obj.configure_logs(:format=>format_hash)
        msg = "Hello, world!"
        formatted_msg = obj.formattedMessage(msg, :log_level => 2)
        formatted_msg.should include(FIXED_TIME.strftime('[%H:%M]'))
        formatted_msg.should include('PROG: ')
        formatted_msg.should include('WARNING: ')
        formatted_msg.should include(msg)
      end
    end
    context 'format options are all nil' do
      it 'should format correctly' do
        obj = Dummy.new
        obj.configure_logs(:format=>{})
        msg = "Hello, world!"
        formatted_msg = obj.formattedMessage(msg, :log_level => 1)
        formatted_msg.should include(msg)
        formatted_msg.should include(FIXED_TIME.strftime('[%Y-%m-%d %H:%M:%S]'))
        formatted_msg.should include('Dummy: ')
        formatted_msg.should include('ERROR: ')
        formatted_msg.should include(msg)
      end
    end
    it 'should accept symbol severities' do
      obj = Dummy.new
      obj.configure_logs()
      msg = "Hello, world!"
      formatted_msg = obj.formattedMessage(msg, :log_level => :error)
      formatted_msg.should include(msg)
      formatted_msg.should include(FIXED_TIME.strftime('[%Y-%m-%d %H:%M:%S]'))
      formatted_msg.should include('Dummy: ')
      formatted_msg.should include('ERROR: ')
      formatted_msg.should include(msg)
    end
  end

  describe '.log' do
    it 'should print to all log handles' do
      handle1 = LogMixin::FakeFileHandle.new
      handle2 = LogMixin::FakeFileHandle.new
      obj = Dummy.new
      obj.configure_logs(:log_handles => [handle1, handle2],
                        :test_logging_internals => true)

      msg1 = "Hello, world!"
      msg2 = "Spam"
      prefix = FIXED_TIME.strftime('[%Y-%m-%d %H:%M:%S]') + ' Dummy: INFO: '
      handle1.msgs.should have(0).messages
      handle2.msgs.should have(0).messages

      obj.log(msg1)
      handle1.msgs.should have(1).message
      handle2.msgs.should have(1).message
      handle1.msgs.last.should == prefix + msg1 + "\n"
      handle2.msgs.last.should == prefix + msg1 + "\n"

      obj.log(msg2)
      handle1.msgs.should have(2).messages
      handle2.msgs.should have(2).messages
      handle1.msgs.last.should == prefix + msg2 + "\n"
      handle2.msgs.last.should == prefix + msg2 + "\n"
    end
    it 'should filter messages of low severity' do
      obj = Dummy.new
      obj.configure_logs(:log_level => :error)

      msg1 = "Hello, world!"
      msg2 = "Spam"
      prefix = FIXED_TIME.strftime('[%Y-%m-%d %H:%M:%S]') + ' Dummy: '
      obj.__handle.msgs.should have(0).messages

      obj.log(msg1, :level => :critical)
      obj.__handle.msgs.should have(1).message
      obj.__handle.msgs.last.should == prefix + 'CRITICAL: ' + msg1 + "\n"

      obj.log('Filter me!')
      obj.__handle.msgs.should have(1).message
      obj.__handle.msgs.last.should == prefix + 'CRITICAL: ' + msg1 + "\n"

      obj.log(msg2, :level => 1)
      obj.__handle.msgs.should have(2).messages
      obj.__handle.msgs.last.should == prefix + 'ERROR: ' + msg2 + "\n"

      obj.log('Filter me!', :level => 2)
      obj.__handle.msgs.should have(2).messages
      obj.__handle.msgs.last.should == prefix + 'ERROR: ' + msg2 + "\n"
    end
    it 'should accept non-standard *message* log levels' do
      obj = Dummy.new
      obj.configure_logs()

      msg1 = "Hello, world!"
      msg2 = "Spam"
      prefix = FIXED_TIME.strftime('[%Y-%m-%d %H:%M:%S]') + ' Dummy: '
      obj.__handle.msgs.should have(0).messages

      obj.log(msg1, :level => -3)
      obj.__handle.msgs.should have(1).message
      obj.__handle.msgs.last.should == prefix + 'Log level -3: ' + msg1 + "\n"

      obj.log('Filter me!', :level => 9)
      obj.__handle.msgs.should have(1).message
      obj.__handle.msgs.last.should == prefix + 'Log level -3: ' + msg1 + "\n"
    end
    it 'should accept non-standard *LogMixin object* log levels' do
      obj = Dummy.new
      obj.configure_logs(:log_level => 6)

      msg1 = "Hello, world!"
      msg2 = "Spam"
      prefix = FIXED_TIME.strftime('[%Y-%m-%d %H:%M:%S]') + ' Dummy: '
      obj.__handle.msgs.should have(0).messages

      obj.log(msg1, :level => -3)
      obj.__handle.msgs.should have(1).message
      obj.__handle.msgs.last.should == prefix + 'Log level -3: ' + msg1 + "\n"

      obj.log('Filter me!', :level => 9)
      obj.__handle.msgs.should have(1).message
      obj.__handle.msgs.last.should == prefix + 'Log level -3: ' + msg1 + "\n"
    end
    it 'should allow setLogLevel to change object\'s log level' do
      obj = Dummy.new
      obj.configure_logs(:log_level => :error)

      msg1 = "Hello, world!"
      msg2 = "Spam"
      prefix = FIXED_TIME.strftime('[%Y-%m-%d %H:%M:%S]') + ' Dummy: '
      obj.__handle.msgs.should have(0).messages

      obj.log(msg1, :level => :debug)
      obj.__handle.msgs.should have(0).messages

      obj.log(msg1, :level => :critical)
      obj.__handle.msgs.should have(1).message
      obj.__handle.msgs.last.should == prefix + 'CRITICAL: ' + msg1 + "\n"

      obj.setLogLevel(:debug)

      obj.log(msg2, :level => :debug)
      obj.__handle.msgs.should have(2).messages
      obj.__handle.msgs.last.should == prefix + 'DEBUG: ' + msg2 + "\n"

      obj.setLogLevel(:error)

      obj.log(msg1, :level => :info)
      obj.__handle.msgs.should have(2).messages
      obj.__handle.msgs.last.should == prefix + 'DEBUG: ' + msg2 + "\n"
    end

    it 'should use Rails logging if Rails is detected' do
      # Begin hacky construction of a mock Rails class with a mock logger
      class Rails
        class << self
          # Hacky-but-best-known way to add attr_accessors for class variables
          attr_accessor :logger
        end
      end
      Rails.logger = Object.new
      class << Rails.logger
        attr_accessor :debug_msgs, :info_msgs, :warn_msgs
        attr_accessor :error_msgs, :fatal_msgs
        def debug(msg); @debug_msgs << msg; end
        def info(msg);  @info_msgs  << msg; end
        def warn(msg);  @warn_msgs  << msg; end
        def error(msg); @error_msgs << msg; end
        def fatal(msg); @fatal_msgs << msg; end
      end
      Rails.logger.debug_msgs = []
      Rails.logger.info_msgs = []
      Rails.logger.warn_msgs = []
      Rails.logger.error_msgs = []
      Rails.logger.fatal_msgs = []

      # Pretend we're using rails for logging now
      # When you're externally removing a constant from another module, you
      #   know it's an ugly hack...
      LogMixin.send(:remove_const, "RAILS")
      LogMixin.const_set("RAILS", true)

      begin
        obj = Dummy.new
        obj.configure_logs(:log_level => :error)
        msg1 = "Hello, world!"
        msg2 = "Spam"

        Rails.logger.debug_msgs.should have(0).messages
        Rails.logger.error_msgs.should have(0).messages
        Rails.logger.fatal_msgs.should have(0).messages

        obj.log(msg1, :level => :debug)
        Rails.logger.debug_msgs.should have(0).messages

        obj.log(msg1, :level => :critical)
        Rails.logger.fatal_msgs.should have(1).message
        Rails.logger.error_msgs.should have(0).messages
        Rails.logger.fatal_msgs.last.should == msg1

        obj.log(msg2, :level => :error)
        Rails.logger.fatal_msgs.should have(1).message
        Rails.logger.error_msgs.should have(1).message
        Rails.logger.info_msgs.should  have(0).messages
        Rails.logger.error_msgs.last.should == msg2

        obj.log(msg2, :level => :info)   # should get filtered
        Rails.logger.fatal_msgs.should have(1).message
        Rails.logger.error_msgs.should have(1).message
        Rails.logger.info_msgs.should  have(0).messages
      ensure
        LogMixin.send(:remove_const, "RAILS")
        LogMixin.const_set("RAILS", false)
      end
    end
  end

  context 'Lazy-initialized log handle' do
    let(:obj) { Dummy.new }
    let(:log_handle_generator) do
      lambda do
        class << obj
          attr_accessor :generated_handle
        end
        obj.generated_handle = LogMixin::FakeFileHandle.new
      end
    end

    it 'should not call the handle generator if nothing is logged' do

      # We haven't even assigned it to obj yet, so it shouldn't work
      lambda { obj.generated_handle }.should raise_error(NoMethodError)

      obj.configure_logs(:test_logging_internals => true,
                         :log_handles => [log_handle_generator])
      # We haven't logged anything yet, so it shouldn't work
      lambda { obj.generated_handle }.should raise_error(NoMethodError)
    end

    it 'should call the generator and log to the returned handle, on #log' do
      # We haven't logged anything yet, so it shouldn't work
      lambda { obj.generated_handle }.should raise_error(NoMethodError)

      obj.configure_logs(:test_logging_internals => true,
                         :log_handles => [log_handle_generator])

      # Now we log something...
      msg = "This should call the filehandle generator!"
      obj.log(msg)
      lambda { obj.generated_handle }.should_not raise_error(NoMethodError)

      # In addition to not raising an error, the generated filehandle should
      # get logged to, of course.
      obj.generated_handle.msgs.should have(1).message
      actual_msg = obj.generated_handle.msgs.first.chomp   # strip newline
      actual_msg.slice(-(msg.length), msg.length).should == msg
    end
  end

  context 'non-instance module usage' do
    it 'should work when called as a module method' do
      # Hack the module to provide accessors for testing
      module LogMixin
        attr_reader :vblm_log_handles, :vblm_log_level, :vblm_format, :__handle
      end

      msg1 = "Hello, world!"
      LogMixin.__handle.msgs.should have(0).messages

      LogMixin.info(msg1)
      LogMixin.__handle.msgs.should have(1).message
      LogMixin.__handle.msgs.last.should match(msg1)
    end
  end
end
