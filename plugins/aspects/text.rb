# -*- coding: utf-8 -*-
description 'Text aspect'

Aspect.create(:text, mime: 'text/plain;charset=utf-8') do
  def accepts?(page); page.mime.text?; end
  def call(context, page)
    context.header['Content-Length'] = page.content.bytesize.to_s
    page.content
  end
end

__END__
@@ locale.yml
cs:
  aspect_text: 'Stažení textu'
de:
  aspect_text: 'Quellcode herunterladen'
en:
  aspect_text: 'Text Download'
fr:
  aspect_text: "Téléchargement en texte"
