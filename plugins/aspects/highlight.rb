# -*- coding: utf-8 -*-
description  'Source code highlighting aspect'
dependencies 'utils/rouge'

Aspect.create(:highlight, priority: 2, layout: true, cacheable: true) do
  def accepts?(page)
    !page.content.empty? && ::Rouge::Lexer.guesses(:mimetype => page.mime.to_s).size == 1
  end

  def call(context, page)
    ::Rouge.highlight(page.content, ::Rouge::Lexer.guess_by_mimetype(page.mime.to_s), 'html')
  end
end

__END__
@@ locale.yml
cs:
  aspect_highlight: 'Zvýrazněný zdroj'
de:
  aspect_highlight: 'Quellcode mit Syntaxhighlighting'
en:
  aspect_highlight: 'Highlighted Source'
fr:
  aspect_highlight: "Source mise en valeur"
