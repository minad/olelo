module Olelo
  class VirtualFS
    def read(name)
      raise NotImplementedError
    end

    def glob(*names)
      raise NotImplementedError
    end

    def mtime(name)
      raise NotImplementedError
    end

    def real_path(name)
      nil
    end

    def size(name)
      read(name).bytesize
    end

    class Native < VirtualFS
      def initialize(dir)
        @dir = dir
      end

      # @override
      def read(name)
        File.read(real_path(name))
      end

      # @override
      def glob(*names)
        names.map do |name|
          Dir[real_path(name)].select {|f| File.file?(f) }
        end.flatten.each do |f|
          yield(self, f[@dir.length+1..-1])
        end
      end

      # @override
      def real_path(name)
        File.join(@dir, name)
      end

      # @override
      def mtime(name)
        File.mtime(real_path(name))
      end

      # @override
      def size(name)
        File.stat(real_path(name)).size
      end
    end

    class Embedded < VirtualFS
      def initialize(file)
        @file = file
        @cache = {}
      end

      # @override
      def read(name)
        @cache[name] ||=
          begin
            code, data = File.read(@file).split('__END__', 2)
            content = nil
            data.to_s.each_line do |line|
            if line =~ /\A@@\s*([^\s]+)\s*/
              if name == $1
                content = ''
              elsif content
                break
              end
            elsif content
              content << line
            end
          end
            content || raise(IOError, "#{name} not found")
          end
      end

      # @override
      def glob(*names)
        code, data = File.read(@file).split('__END__', 2)
        data.to_s.each_line do |line|
          if line =~ /\A@@\ss*([^\s]+)\s*/ && names.any? {|pattern| File.fnmatch(pattern, $1) }
            yield(self, $1)
          end
        end
      end

      # @override
      def mtime(name)
        File.mtime(@file)
      end
    end

    class Union < VirtualFS
      def initialize(*fs)
        @fs = fs.compact
      end

      # @override
      def glob(*names, &block)
        @fs.each {|fs| fs.glob(*names, &block) }
      end

      %w(read mtime real_path size).each do |method|
        class_eval %{
          def #{method}(*args)
            result = nil
            @fs.any? do |fs|
              begin
                result = fs.#{method}(*args)
              rescue
              end
            end || raise(IOError, "#{method}(\#{args.map(&:inspect).join(', ')}) failed")
            result
          end
        }
      end

    end

  end
end
