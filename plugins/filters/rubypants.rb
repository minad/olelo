description 'Filter which fixes punctuation'
require 'rubypants'

Filter.create :rubypants do |context, content|
  ::RubyPants.new(content).to_html
end
