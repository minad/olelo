description 'Pandoc filter'
require 'pandoc-ruby'

Filter.create :pandoc do |context, content|
  PandocRuby.convert(content, from: options[:from], to: options[:to])
end

