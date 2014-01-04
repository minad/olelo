# -*- coding: utf-8 -*-
description 'Page information aspect'

Aspect.create(:pageinfo, priority: 4, cacheable: true) do
  def call(context, page)
    @page = page
    render :pageinfo
  end
end

__END__
@@ pageinfo.slim
table
  tbody
    tr
      td= :name.t
      td= @page.name
    tr
      td= :attribute_title.t
      td= @page.title
    tr
      td= :attribute_description.t
      td= @page.attributes['description']
    - if @page.version
      tr
        td= :last_modified.t
        td= date @page.version.date
      tr
        td= :version.t
        td.version = @page.version
      tr
        td= :author.t
        td= @page.version.author.name
      tr
        td= :comment.t
        td= @page.version.comment
    tr
      td= :type.t
      td= @page.mime.comment.blank? ? @page.mime : "#{@page.mime.comment} (#{@page.mime})"
    - if !@page.content.empty?
      tr
        td= :download.t
        td
          a href=build_path(@page, aspect: 'download') = :download.t
@@ locale.yml
cs:
  aspect_pageinfo: 'Informace o stránce'
  download: 'Stáhnout'
  type: 'Typ'
de:
  aspect_pageinfo: 'Seiten-Information'
  download: 'Herunterladen'
  type: 'Typ'
en:
  aspect_pageinfo: 'Page Information'
  download: 'Download'
  type: 'Type'
fr:
  aspect_pageinfo: "Page d'information"
  download: "Télécharger"
  type: "Type"
