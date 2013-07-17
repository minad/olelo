module Olelo
  class Config
    include Enumerable

    attr_reader :base, :hash

    def initialize(base = nil)
      @hash = {}
      @base = base.freeze
    end

    def [](key)
      key = key.to_s
      if i = key.index('.')
        not_found(key) unless Config === hash[key[0...i]]
        hash[key[0...i]][key[i+1..-1]]
      else
        not_found(key) if !hash.include?(key)
        hash[key]
      end
    end

    def []=(key, value)
      key = key.to_s
      if i = key.index('.')
        child(key[0...i])[key[i+1..-1]] = value
      elsif Hash === value
        child(key).update(value)
      else
        hash[key] = value.freeze
      end
    end

    def update(hash)
      hash.each_pair do |key, value|
        self[key] = value
      end
    end

    def load(file)
      load!(file) if File.file?(file)
    end

    def load!(file)
      update(Util.yaml_load_file(file))
    end

    def each(&block)
      hash.each(&block)
    end

    def self.instance
      @instance ||= Config.new
    end

    def self.[](key)
      instance[key]
    end

    def to_hash
      h = Hash.with_indifferent_access
      hash.each_pair do |k, v|
        h[k] = Config === v ? v.to_hash : v
      end
      h
    end

    def freeze
      hash.freeze
      super
    end

    private

    def not_found(key)
      raise(NameError, "Configuration key #{base ? "#{base}.#{key}" : key} not found")
    end

    def child(key)
      if child = hash[key]
        raise "Configuration key #{key} is already used" unless Config === child
        child
      else
        hash[key] = Config.new(base ? "#{base}.#{key}" : key)
      end
    end
  end
end
