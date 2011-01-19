description 'Maruku/Markdown text filter'
require 'maruku'

Filter.create :maruku do |context, content|
  Filter::Maruku.new(content).to_html
end
