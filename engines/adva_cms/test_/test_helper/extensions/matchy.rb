module Matchy
  module Expectations
    class Base
      # overwritten to take options, too
      def initialize(expected, test_case, options = {})
        @expected = expected
        @test_case = test_case
        @options = options
      end
    end
    
    module TestCaseExtensions
      def be_nil
        Matchy::Expectations::Be.new(nil, self)
      end

      def be_true
        Matchy::Expectations::Be.new(true, self)
      end

      def be_false
        Matchy::Expectations::Be.new(false, self)
      end

      def be_instance_of(expected)
        Matchy::Expectations::BeInstanceOf.new(expected, self)
      end

      def be_kind_of(expected)
        Matchy::Expectations::BeKindOf.new(expected, self)
      end

      def be_empty
        Matchy::Expectations::BeEmpty.new(nil, self)
      end

      def be_blank
        Matchy::Expectations::BeBlank.new(nil, self)
      end

      def be_valid
        Matchy::Expectations::BeValid.new(nil, self)
      end

      def respond_to(expected)
        Matchy::Expectations::RespondTo.new(expected, self)
      end

      def validate_presence_of(attribute, options = {})
        Matchy::Expectations::ValidatePresenceOf.new(attribute, self, options)
      end

      def validate_uniqueness_of(attribute, options = {})
        Matchy::Expectations::ValidateUniquenessOf.new(attribute, self, options)
      end

      def validate_length_of(attribute, options = {})
        Matchy::Expectations::ValidateLengthOf.new(attribute, self, options)
      end

      def belong_to(expected, options = {})
        Matchy::Expectations::Association.new(self, :belongs_to, expected, options)
      end

      def have_one(expected, options = {})
        Matchy::Expectations::Association.new(self, :has_one, expected, options)
      end

      def have_many(expected, options = {})
        Matchy::Expectations::Association.new(self, :has_many, expected, options)
      end
      
      def have_tag(*args, &block)
        Matchy::Expectations::AssertSelect.new(:assert_select, self, *args, &block)
      end
    end

    class << self
      def matcher(name, failure_message, negative_failure_message, &block)
        matcher = Class.new(Base) do
          define_method :matches?, &block
          
          define_method :failure_message do 
            failure_message % [@receiver.inspect, @expected.inspect, @options.inspect]
          end
          
          define_method :negative_failure_message do 
            negative_failure_message % [@receiver.inspect, @expected.inspect, @options.inspect]
          end
        end
        const_set(name, matcher)
      end
    end

    matcher "Be", 
            "Expected %s to be %s.", 
            "Expected %s not to be %s." do |receiver|
      @receiver = receiver
      @expected.class === receiver
    end

    matcher "BeInstanceOf", 
            "Expected %s to be an instance of %s.", 
            "Expected %s not to be an instance of %s." do |receiver|
      @receiver = receiver
      receiver.instance_of? @expected
    end

    matcher "BeKindOf", 
            "Expected %s to be a kind of %s.", 
            "Expected %s not to be a kind of %s." do |receiver|
      @receiver = receiver
      receiver.kind_of? @expected
    end

    matcher "BeEmpty", 
            "Expected %s to be empty.", 
            "Expected %s not to be empty." do |receiver|
      @receiver = receiver
      receiver.empty?
    end

    matcher "BeBlank", 
            "Expected %s to be blank.", 
            "Expected %s not to be blank." do |receiver|
      @receiver = receiver
      receiver.blank?
    end

    matcher "BeValid", 
            "Expected %s to be valid.", 
            "Expected %s not to be valid." do |receiver|
      @receiver = receiver
      receiver.valid?
    end

    matcher "RespondTo", 
            "Expected %s to respond to %s.", 
            "Expected %s not to respond to %s." do |receiver|
      @receiver = receiver
      receiver.respond_to? @expected
    end

    matcher "ValidatePresenceOf", 
            "Expected %s to validate the presence of %s.", 
            "Expected %s not to validate the presence of %s." do |receiver|
      @receiver = receiver
      
      # stubs the method given as @options[:if] on the receiver
      RR.stub(receiver).__creator__.create(@options[:if]).returns(true) if @options[:if]
      
      receiver.send("#{@expected}=", nil)
      !receiver.valid? && receiver.errors.invalid?(@expected)
    end

    matcher "ValidateLengthOf", 
            "Expected %s to validate the length of %s (with %s).", 
            "Expected %s not to validate the length of %s (with %s)." do |receiver|
      @receiver = receiver

      max = @options[:within] || @options[:is]
      max = max.last if max.respond_to?(:last)

      value = receiver.send(@expected).to_s
      value = 'x' if value.blank?
      value = (value * (max  + 1))[0, max + 1]
      
      receiver.send("#{@expected}=", value)
      !receiver.valid? && receiver.errors.invalid?(@expected)
    end

    class ValidateUniquenessOf < Base
      def matches?(model)
        RR.reset
        @receiver = model
        args = @options[:scope] ? RR.satisfy {|args| args.first =~ /.#{@options[:scope]} (=|IS) \?/ } : RR.anything
        RR.mock(model.class).exists?.with(args).returns true
        !model.valid? && model.errors.invalid?(@expected)
        RR.verify
        true
      rescue RR::Errors::RRError => e
        false
      end

      def failure_message
        "Expected #{@receiver.class.name} to validate the uniqueness of #{@expected.inspect}" +
        (@options[:scope] ? " with scope #{@options[:scope].inspect}." : '.')
      end

      def negative_failure_message
        "Expected #{@receiver.class.name} not to validate the uniqueness of #{@expected.inspect}" +
        (@options[:scope] ? " with scope #{@options[:scope].inspect}." : '.')
      end
    end

    class Association < Base
      def initialize(test_case, type, expected, options = {})
        @type = type
        @options = options
        super expected, test_case
      end

      def matches?(model)
        @receiver = model
        model = model.class if model.is_a? ActiveRecord::Base
        !!model.reflect_on_all_associations(@type).find do |a|
          a.name == @expected and options_match?(a.options)
        end
      end

      def options_match?(options)
        @options.each do |key, value|
          return false if !options.has_key?(key) || options[key] != value
        end
        true
      end

      def failure_message
        "Expected #{@receiver.class.name} to #{@type} #{@expected.inspect}."
      end

      def negative_failure_message
        "Expected #{@receiver.class.name} not to #{@type} #{@expected.inspect}."
      end
    end
    
      class AssertSelect < Base
        def initialize(assertion, test_case, *args, &block)
          super nil, test_case
          @assertion = assertion
          @args = args
          @block = block
        end

        def matches?(response_or_text, &block)
          if ActionController::TestResponse === response_or_text and
                   response_or_text.headers.key?('Content-Type') and
                   !response_or_text.headers['Content-Type'].blank? and
                   response_or_text.headers['Content-Type'].to_sym == :xml
            @args.unshift(HTML::Document.new(response_or_text.body, false, true).root)
          elsif String === response_or_text
            @args.unshift(HTML::Document.new(response_or_text).root)
          end
          @block = block if block
          begin
            @test_case.send(@assertion, *@args, &@block)
          rescue ::Test::Unit::AssertionFailedError => @error
          end

          @error.nil?
        end

        def failure_message; @error.message; end
        def negative_failure_message; "should not #{description}, but did"; end

        def description
          case @assertion
            when :assert_select       then "have tag#{format_args(*@args)}"
            when :assert_select_email then "send email#{format_args(*@args)}"
          end
        end

        protected
          def format_args(*args)
            return "" if args.empty?
            return "(#{arg_list(*args)})"
          end

          def arg_list(*args)
            args.collect do |arg|
              arg.respond_to?(:description) ? arg.description : arg.inspect
            end.join(", ")
          end
      end
  end
end