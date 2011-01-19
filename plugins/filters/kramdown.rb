description 'Kramdown markdown converter'
require 'kramdown'

Filter.create :kramdown do |context, content|
  doc = Filter::Kramdown::Document.new(content)
  options[:latex] ? doc.to_latex : doc.to_html
end
