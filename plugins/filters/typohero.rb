description 'Filter which fixes punctuation'
require 'typohero'

Filter.create :typohero do |context, content|
  ::TypoHero.enhance(content)
end
