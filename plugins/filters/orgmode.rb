description 'Emacs org-mode filter'
require 'org-ruby'

Filter.create :orgmode do |context, content|
  ::Orgmode::Parser.new(content).to_html
end
