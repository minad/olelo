# -*- coding: utf-8 -*-
description 'Source aspect'

Aspect.create(:source, priority: 3, cacheable: true) do
  def accepts?(page); page.mime.text?; end
  def call(context, page); "<pre>#{escape_html page.content}</pre>"; end
end

__END__
@@ locale.yml
cs:
  aspect_source: 'Zdroj stránky'
de:
  aspect_source: 'Quellcode'
en:
  aspect_source: 'Page Source'
fr:
  aspect_source: "Source de la page"
