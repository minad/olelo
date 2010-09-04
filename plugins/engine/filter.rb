description 'Filter pipeline engine'
dependencies 'engine/engine'

class Olelo::MandatoryFilterNotFound < NameError; end

# Basic linear filter
class Olelo::Filter
  include PageHelper
  include Templates
  extend Factory

  attr_accessor :previous
  attr_reader :name, :description, :plugin, :options

  def initialize(name, options)
    @name        = name.to_s
    @plugin      = options[:plugin] || Plugin.current(1) || Plugin.current
    @description = options[:description] || @plugin.description
  end

  def configure(options)
    @options = options
  end

  def call(context, content)
    dup.call!(context, content)
  end

  def call!(context, content)
    content = previous ? previous.call(context, content) : content
    filter(context, content)
  end

  def definition
    previous ? "#{previous.definition} > #{name}" : name
  end

  def self.register(name, klass, options = {})
    super(name, klass.new(name, options))
  end

  def self.create(name, options = {}, &block)
    klass = Class.new(self)
    klass.class_eval { define_method(:filter, &block) }
    register(name, klass, options)
  end
end

# Filter which supports subfilters
class Olelo::AroundFilter < Olelo::Filter
  attr_accessor :sub

  def subfilter(context, content)
    sub ? sub.call(context, content) : content
  end

  def definition
    sub ? "#{super} (#{sub.definition})" : super
  end
end

class Olelo::FilterEngine < Engine
  def initialize(name, options, filter)
    super(name, options)
    @filter = filter
  end

  def output(context)
    @filter.call(context, context.page.content.dup)
  end

  def definition
    @filter.definition
  end
end

# Filter DSL
class FilterDSL
  # Build filter class
  class FilterBuilder
    def initialize(name, filter = nil)
      @name = name
      @filter = filter
    end

    # Add optional filter
    def filter(name, options = nil, &block)
      add(name, false, options, &block)
    end

    # Add mandatory filter
    def filter!(name, options = nil, &block)
      add(name, true, options, &block)
    end

    # Add filter with method name.
    # Mandatory filters must end with !
    def method_missing(name, options = nil, &block)
      name = name.to_s
      name.ends_with?('!') ? filter!(name[0..-2], options, &block) : filter(name, options, &block)
    end

    def build(&block)
      instance_eval(&block)
      @filter
    end

    private

    def add(name, mandatory, options = nil, &block)
      filter = Filter[name] rescue nil
      if filter
        filter = filter.dup
        filter.configure((options || {}).with_indifferent_access)
        filter.previous = @filter
        @filter = filter
        if block
          raise "Filter '#{name}' does not support subfilters" if !(AroundFilter === @filter)
          @filter.sub = FilterBuilder.new(@name).build(&block)
        end
      else
        if mandatory
          raise MandatoryFilterNotFound, "Engine '#{@name}' not created because mandatory filter '#{name}' is not available"
        else
          Plugin.current.logger.warn "Optional filter '#{name}' not available"
        end
        @filter = FilterBuilder.new(@name, @filter).build(&block) if block
      end
      self
    end
  end

  # Build engine class
  class EngineBuilder
    def initialize(name)
      @name = name
      @options = {}
    end

    def build(&block)
      instance_eval(&block)
      raise("No filters defined for engine '#{name}'") if !@filter
      FilterEngine.new(@name, @options, @filter)
    end

    def filter(&block)
      @filter = FilterBuilder.new(@name).build(&block)
      self
    end

    def mime(mime);         @options[:mime] = mime;       self; end
    def accepts(accepts);   @options[:accepts] = accepts; self; end
    def needs_layout;       @options[:layout] = true;     self; end
    def has_priority(prio); @options[:priority] = prio;   self; end
    def is_cacheable;       @options[:cacheable] = true;  self; end
    def adds_title;         @options[:title] = true;      self; end
  end

  # Register regexp filter
  def regexp(name, *regexps)
    Filter.create(name, :description => 'Regular expression filter') do |context, content|
      regexps.each_slice(2) { |regexp, sub| content.gsub!(regexp, sub) }
      content
    end
  end

  # Register engine
  def engine(name, &block)
    Engine.register(EngineBuilder.new(name).build(&block))
    Plugin.current.logger.debug "Filter engine '#{name}' successfully created"
  rescue MandatoryFilterNotFound => ex
    Plugin.current.logger.warn ex.message
  rescue Exception => ex
    Plugin.current.logger.error ex
  end
end

def setup
  file = File.join(Config.config_path, 'engines.rb')
  FilterDSL.new.instance_eval(File.read(file), file)
end
