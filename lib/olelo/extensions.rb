class Module
  # Generate accessor method with question mark
  #
  # @param [String, Symbol...] attrs Attributes to generate setter for
  # @return [void]
  #
  def attr_reader?(*attrs)
    attrs.each do |a|
      module_eval "def #{a}?; !!@#{a}; end"
    end
  end

  # Generate attribute setter
  #
  # A setter accepts an argument to
  # set a value. It acts as a getter without an argument.
  #
  # @see Ruby facets
  # @param [String, Symbol...] attrs Attributes to generate setter for
  # @return [void]
  #
  def attr_setter(*attrs)
    code, made = '', []
    attrs.each do |a|
      code << "def #{a}(*a); a.size > 0 ? (@#{a}=a[0]; self) : @#{a} end\n"
      made << a.to_sym
    end
    module_eval(code)
    made
  end

  # Redefine a module method
  #
  # Replaces alias_method_chain and allows to call
  # overwritten method via super.
  #
  # @param [Symbol, String] name of method
  # @yield New method block
  # @return [void]
  #
  def redefine_method(name, &block)
    if instance_methods(false).any? {|x| x.to_s == name.to_s }
      method = instance_method(name)
      mod = Module.new do
        define_method(name) {|*args| method.bind(self).call(*args) }
      end
      remove_method(name)
      include(mod)
    end
    include(Module.new { define_method(name, &block) })
  end
end

class Hash
  # Stolen from rails
  class WithIndifferentAccess < Hash
    def initialize(arg = {})
      if Hash === arg
        super()
        update(arg)
      else
        super(arg)
      end
    end

    alias_method :regular_include, :include?
    alias_method :regular_writer, :[]=
    alias_method :regular_update, :update

    def default(key = nil)
      if Symbol === key && regular_include(key = key.to_s)
        self[key]
      else
        super
      end
    end

    def []=(key, value)
      regular_writer(convert_key(key), value)
      value
    end

    def update(other)
      other.each_pair {|key, value| regular_writer(convert_key(key), value) }
      self
    end

    alias_method :merge!, :update

    def key?(key)
      super(convert_key(key))
    end

    alias_method :include?, :key?
    alias_method :has_key?, :key?
    alias_method :member?, :key?

    def fetch(key, *extras)
      super(convert_key(key), *extras)
    end

    def values_at(*indices)
      indices.collect {|key| self[convert_key(key)]}
    end

    def dup
      WithIndifferentAccess.new(self)
    end

    def merge(hash)
      self.dup.update(hash)
    end

    def delete(key)
      super(convert_key(key))
    end

    def to_hash
      Hash.new(default).merge(self)
    end

    protected

    def convert_key(key)
      Symbol === key ? key.to_s : key
    end
  end

  def with_indifferent_access
    hash = WithIndifferentAccess.new(self)
    hash.default = self.default
    hash
  end

  def self.with_indifferent_access(arg = {})
    WithIndifferentAccess.new(arg)
  end
end

class Object
  # Returns true if object is empty or false
  #
  # @return [Boolean]
  #
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end

  # Try to call method if it exists or return nil
  #
  # @param [String, Symbol] name Method name
  # @param args Method arguments
  # @return Method result or nil
  #
  def try(name, *args)
    respond_to?(name) ? send(name, *args) : nil
  end
end

class String
  # Try to force encoding
  #
  # Force encoding of string and revert
  # to original encoding if string has no valid encoding
  #
  # @param [Encoding, String] enc New encoding
  # @return self
  #
  def try_encoding(enc)
    old_enc = encoding
    if old_enc != enc
      force_encoding(enc)
      force_encoding(old_enc) if !valid_encoding?
    end
    self
  end

  # Check if string starts with s
  #
  # @param [String] s
  # @return [Boolean]
  #
  def starts_with?(s)
    index(s) == 0
  end

  # Check if string ends with s
  #
  # @param [String] s
  # @return [Boolean]
  #
  def ends_with?(s)
    rindex(s) == size - s.size
  end

  # Clean up path (replaces '..', '.' etc.)
  #
  # @return [String] cleaned path
  #
  def cleanpath
    names = []
    split('/').each do |name|
      case name
      when '..'
        names.pop
      when '.'
      when ''
      else
        names.push name
      end
    end
    names.join('/')
  end

  # Concatenate path components with /
  #
  # Calls {#cleanpath} on result.
  #
  # @param [String] path component
  # @return [String] this string concatenated with path
  #
  def /(path)
    "#{self}/#{path}".cleanpath
  end
end
