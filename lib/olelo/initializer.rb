module Olelo
  class<< self
    attr_accessor :logger
  end

  class Initializer
    include Util

    def self.initialize(logger)
      @instance ||= Initializer.new(logger)
    end

    def initialize(logger)
      Olelo.logger = logger
      init_locale
      init_templates
      init_plugins
      show_routes if Olelo.logger.debug?
      init_scripts
    end

    private

    def init_locale
      Locale.locale = Config['locale']
      Locale.add(yaml_load_file(File.join(File.dirname(__FILE__), 'locale.yml')))
    end

    def init_templates
      Templates.enable_caching if Config['production']
      Templates.loader = proc do |name|
        VirtualFS::Union.new(VirtualFS::Native.new(File.join(File.dirname(__FILE__), 'views')),
                             *Plugin.loaded.map(&:virtual_fs)).read(name)
      end
    end

    def init_plugins
      # Load locale provided by plugin
      Plugin.after(:load) do
        virtual_fs.glob('locale.yml') do |fs, name|
          Locale.add(yaml_load(fs.read(name)))
        end
      end

      # Configure plugin system
      Plugin.disabled = Config['disabled_plugins'].to_a
      Plugin.dir = Config['plugins_path']

      Plugin.load_all
      Plugin.start
    end

    def show_routes
      Application.router.each do |method, router|
        Olelo.logger.debug method
        router.each do |name, pattern, keys, function|
          Olelo.logger.debug "#{name} -> #{pattern.inspect}"
        end
      end
    end

    def init_scripts
      Dir[File.join(Config['initializers_path'], '*.rb')].sort_by do |f|
        File.basename(f)
      end.each do |f|
        Olelo.logger.debug "Running script initializer #{f}"
	instance_eval(File.read(f), f)
      end
    end
  end
end
