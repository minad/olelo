description 'Key/value store'
require 'delegate'

# Simple interface to key/value stores with Hash-like interface.
#
# Store supports a subset of the Moneta interface,
# Moneta can be used as a drop-in replacement.
# It is recommended to wrap the moneta store in a Store::Delegated
# to only expose the Store interface.
#
# @abstract
class Store
  extend Factory

  # Exists the value with key
  #
  # @param [String] key
  # @return [Boolean]
  # @api public
  # @abstract
  def key?(key)
    raise NotImplementedError
  end

  # Read value with key. Return nil if the key doesn't exist
  #
  # @param [String] key
  # @return [Object] value
  # @api public
  # @abstract
  def [](key)
    raise NotImplementedError
  end

  # Write value with key
  #
  # @param [String] key
  # @param [Object] value
  # @return value
  # @api public
  # @abstract
  def []=(key, value)
    raise NotImplementedError
  end

  # Delete the key from the store and return the current value
  #
  # @param [String] key
  # @return [Object] current value
  # @api public
  # @abstract
  def delete(key)
    raise NotImplementedError
  end

  # Clear all keys in this store
  #
  # @return [void]
  # @api public
  # @abstract
  def clear
    raise NotImplementedError
  end

  protected

  # Serialize value
  #
  # @param [Object] value Serializable object
  # @return [String] serialized object
  # @api private
  def serialize(value)
    Marshal.dump(value)
  end

  # Deserialize value
  #
  # @param [String] value Serialized object
  # @return [Object] Deserialized object
  # @api private
  def deserialize(value)
    value && Marshal.load(value)
  end

  # Create store instance
  #
  # @param [Config] Store configuration
  # @return [Store]
  # @api public
  def self.create(config)
    self[config[:type]].new(config[config[:type]])
  end

  # Delegated store
  Delegated = DelegateClass(Store)

  # Synchronized store
  def self.Synchronized(type)
    klass = Class.new
    klass.class_eval %{
      def initialize(config)
        @store = #{type.name}.new(config)
        @lock = Mutex.new
      end

      def method_missing(*args)
        @lock.synchronize { @store.send(*args) }
      end
    }
    klass
  end

  # Memory based store (uses hash)
  class Memory < Delegated
    def initialize(config)
      super({})
    end
  end

  register :memory, Memory

  # Memcached client
  class Memcached < Delegated
    def initialize(config)
      super(Store::Synchronized(Native).new(config))
    rescue LoadError
      super(Ruby.new(config))
    end

    # Uses the memcached gem
    class Native < Store
      include Util

      def initialize(config)
        require 'memcached'
        @server = ::Memcached.new(config[:server], :prefix_key => (config[:prefix] rescue nil))
      end

      # @override
      def key?(key)
        @server.get(md5(key), false)
        true
      rescue ::Memcached::NotFound
        false
      end

      # @override
      def [](key)
        @server.get(md5(key))
      rescue ::Memcached::NotFound
      end

      # @override
      def []=(key, value)
        @server.set(md5(key), value)
        value
      end

      # @override
      def delete(key)
        key = md5(key)
        value = @server.get(key)
        @server.delete(key)
        value
      rescue ::Memcached::NotFound
      end

      # @override
      def clear
        @server.flush
      end
    end

    # Uses the dalli gem (memcache-client successor)
    class Ruby < Store
      include Util

      def initialize(config)
        require 'dalli'
        @server = ::Dalli::Client.new(config[:server], :namespace => (config[:prefix] rescue nil))
      end

      # @override
      def key?(key)
        !@server.get(md5(key)).nil?
      end

      # @override
      def [](key)
        deserialize(@server.get(md5(key)))
      end

      # @override
      def []=(key, value)
        @server.set(md5(key), serialize(value))
        value
      end

      # @override
      def delete(key)
        key = md5(key)
        value = deserialize(@server.get(key))
        @server.delete(key)
        value
      end

      # @override
      def clear
        @server.flush_all
      end
    end
  end

  register :memcached, Memcached

  # PStore based store
  class PStore < Store
    def initialize(config)
      require 'pstore'
      FileUtils.mkpath(::File.dirname(config[:file]))
      @store = ::PStore.new(config[:file])
    end

    # @override
    def key?(key)
      @store.transaction(true) { @store.root?(key) }
    end

    # @override
    def [](key)
      @store.transaction(true) { @store[key] }
    end

    # @override
    def []=(key, value)
      @store.transaction { @store[key] = value }
    end

    # @override
    def delete(key)
      @store.transaction { @store.delete(key) }
    end

    # @override
    def clear
      @store.transaction do
        @store.roots.each do |key|
          @store.delete(key)
        end
      end
    end
  end

  register :pstore, Synchronized(PStore)

  # File based store
  class File < Store
    def initialize(config)
      @root = config[:root]
    end

    # @override
    def key?(key)
      ::File.exist?(store_path(key))
    end

    # @override
    def [](key)
      deserialize(::File.read(store_path(key)))
    rescue Errno::ENOENT
    end

    # @override
    def []=(key, value)
      temp_file = ::File.join(@root, "value-#{$$}-#{Thread.current.object_id}")
      FileUtils.mkpath(@root)
      ::File.open(temp_file, 'wb') {|file| file.write(serialize(value)) }
      path = store_path(key)
      FileUtils.mkpath(::File.dirname(path))
      ::File.unlink(path) if ::File.exist?(path)
      FileUtils.mv(temp_file, path)
    rescue
      ::File.unlink(temp_file) rescue nil
    ensure
      value
    end

    # @override
    def delete(key)
      value = self[key]
      ::File.unlink(store_path(key))
      value
    rescue Errno::ENOENT
    end

    # @override
    def clear
      temp_dir = "#{@root}-#{$$}-#{Thread.current.object_id}"
      FileUtils.mv(@root, temp_dir)
      FileUtils.rm_rf(temp_dir)
    rescue Errno::ENOENT
    end

    protected

    def store_path(key)
      key = Util.md5(key)
      ::File.join(@root, key[0..1], key[2..-1])
    end
  end

  register :file, File
end

Olelo::Store = Store
