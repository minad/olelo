# -*- coding: utf-8 -*-
description 'Download aspect'

Aspect.create(:download, mime: nil) do
  def accepts?(page); !page.content.empty?; end
  def call(context, page)
    name = page.root? ? :root.t : page.name.gsub(/[^\w.\-_]/, '_')
    context.header['Content-Disposition'] = %{attachment; filename="#{name}"}
    context.header['Content-Length'] = page.content.bytesize.to_s
    page.content
  end
end

__END__
@@ locale.yml
cs:
  aspect_download: 'Stažení (neupraveno)'
de:
  aspect_download: 'Herunterladen'
en:
  aspect_download: 'Download'
fr:
  aspect_download: "Téléchargement"
