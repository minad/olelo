#!/usr/bin/env rackup

app_path = ::File.expand_path(::File.dirname(__FILE__))
$: << ::File.join(app_path, 'lib')

# We want to read all text data as UTF-8
Encoding.default_external = Encoding::UTF_8

require 'fileutils'
require 'rack/relative_redirect'
require 'olelo'
require 'securerandom'

Olelo::Config.instance['app_path'] = app_path
Olelo::Config.instance['config_path'] = ::File.join(app_path, 'config')
Olelo::Config.instance['initializers_path'] = ::File.join(app_path, 'config', 'initializers')
Olelo::Config.instance['plugins_path'] = ::File.join(app_path, 'plugins')
Olelo::Config.instance['rack.session_secret'] = SecureRandom.hex
Olelo::Config.instance.load!(::File.join(app_path, 'config', 'config.yml.default'))

puts 'WARNING: Environment variable $WIKI_CONFIG is deprecated, use $OLELO_CONFIG instead' if ENV['WIKI_CONFIG']

config_file = ENV['OLELO_CONFIG'] || ENV['WIKI_CONFIG']
unless config_file
  path = ::File.join(app_path, 'config', 'config.yml')
  config_file = path if File.exists?(path)
end

if Dir.pwd == app_path
  puts "Serving from Olelo application directory #{app_path}"
  data_path = File.join(app_path, '.wiki')
  Olelo::Config.instance['repository.git'] = { path: ::File.join(data_path, 'repository'), bare: false }
  Olelo::Config.instance['cache_store'] = { type: 'HashFile', 'HashFile.dir' => ::File.join(data_path, 'cache') }
  Olelo::Config.instance['authentication.yamlfile.store'] = ::File.join(data_path, 'users.yml')
  Olelo::Config.instance['log.file'] = ::File.join(data_path, 'log')
elsif File.directory?(::File.join(Dir.pwd, '.git'))
  puts "Serving out of repository #{Dir.pwd}"
  data_path = File.join(Dir.pwd, '.wiki')
  Olelo::Config.instance['repository.git'] = { path: Dir.pwd, bare: false }
  Olelo::Config.instance['cache_store'] = { type: 'HashFile', 'HashFile.dir' => ::File.join(data_path, 'cache') }
  Olelo::Config.instance['authentication.yamlfile.store'] = ::File.join(data_path, 'users.yml')
  Olelo::Config.instance['log.file'] = ::File.join(data_path, 'log')
elsif !config_file
  puts 'No git repository found, please create your own configuration file!'
  exit 1
end

if config_file
  puts "Loading configuration from #{config_file}"
  Olelo::Config.instance.load!(config_file)
end

Olelo::Config.instance.freeze

FileUtils.mkpath ::File.dirname(Olelo::Config['log.file'])
logger = ::Logger.new(Olelo::Config['log.file'], :monthly, 10240000)
logger.level = ::Logger.const_get(Olelo::Config['log.level'])

Olelo::Initializer.initialize(logger)

# Doesn't work currently, rack issue #241
# if !Olelo::Config['production']
#   # Rack::Lint injector
#   module UseLint
#     def use(middleware, *args, &block)
#       super Rack::Lint if middleware != Rack::Lint
#       super
#     end
#     def run(app)
#       use Rack::Lint
#       super
#     end
#   end
#   class << self; include UseLint; end
# end

use Rack::Runtime
use Rack::ShowExceptions unless Olelo::Config['production']

if Olelo::Config['rack.deflater']
  use Rack::Deflater
end

use Olelo::Middleware::StaticCache
use Rack::Static, urls: ['/static'], root: app_path

use Rack::Session::Cookie, key: 'olelo.session', secret: Olelo::Config['rack.session_secret']

if Olelo::Config['production']
  require 'rack/protection'
  use Rack::Protection
end

#require 'rack/perftools_profiler'
#use Rack::PerftoolsProfiler

class LoggerOutput
  def initialize(logger); @logger = logger; end
  def write(text); @logger << text; end
end

use Rack::MethodOverride
use Rack::CommonLogger, LoggerOutput.new(logger)
use Rack::RelativeRedirect
use Rack::ContentLength
use Olelo::Middleware::ForceEncoding
run Olelo::Application.new

logger.info "Olelo started in #{Olelo::Config['production'] ? 'production' : 'development'} mode"
