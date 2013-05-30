# -*- encoding: utf-8 -*-
require File.dirname(__FILE__) + '/lib/olelo/version'
require 'date'

Gem::Specification.new do |s|
  s.name              = 'olelo'
  s.version           = Olelo::VERSION
  s.date              = Date.today.to_s
  s.authors           = ['Daniel Mendler']
  s.email             = ['mail@daniel-mendler.de']
  s.summary           = 'Olelo is a git-based wiki.'
  s.description       = 'Olelo is a git-based wiki which supports many markup languages, tags, embedded TeX and much more. It can be extended through plugins.'
  s.homepage          = 'http://gitwiki.org/'
  s.rubyforge_project = s.name

  s.files         = `git ls-files | grep -P -v '^tools/'`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = %w(lib)

  s.required_ruby_version = '>= 1.9.2'

  s.add_runtime_dependency('RedCloth', ['~> 4.2.9'])
  s.add_runtime_dependency('creole', ['~> 0.5.0'])
  s.add_runtime_dependency('evaluator', ['~> 0.1.6'])
  s.add_runtime_dependency('mimemagic', ['~> 0.2.0'])
  s.add_runtime_dependency('multi_json', ['~> 1.7.3'])
  s.add_runtime_dependency('nokogiri', ['~> 1.5.5'])
  s.add_runtime_dependency('rack', ['~> 1.5.0'])
  s.add_runtime_dependency('redcarpet', ['~> 2.3.0'])
  s.add_runtime_dependency('rugged', ['~> 0.18.0.b1'])
  s.add_runtime_dependency('slim', ['~> 2.0.0'])
  s.add_runtime_dependency('moneta', ['~> 0.7.0'])
  s.add_runtime_dependency('rouge', ['~> 0.3.6'])

  s.add_development_dependency('bacon', ['~> 1.1.0'])
  s.add_development_dependency('rack-test', ['~> 0.6.2'])
  s.add_development_dependency('rake', ['>= 0.8.7'])
  s.add_development_dependency('sass', ['~> 3.2.3'])
end
