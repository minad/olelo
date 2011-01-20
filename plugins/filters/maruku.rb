description 'Maruku/Markdown text filter'
require 'maruku'

Filter.create :maruku do |context, content|
  Maruku.new(content).to_html
end
