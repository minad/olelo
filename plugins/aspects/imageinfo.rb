# -*- coding: utf-8 -*-
description 'Image information aspect'
dependencies 'utils/image_magick'

Aspect.create(:imageinfo, priority: 1, cacheable: true, accepts: %r{\Aimage/}) do
  def call(context, page)
    @page = page
    identify = ImageMagick.identify('-format', "%m\n%h\n%w\n%[EXIF:*]", '-').run(page.content).split("\n")
    @type = identify[0]
    @geometry = "#{identify[1]}x#{identify[2]}"
    @exif = identify[3..-1].to_a.map {|line| line.sub(/^exif:/, '').split('=', 2) }
    render :imageinfo
  end
end

__END__
@@ imageinfo.slim
p
  a href=build_path(@page, aspect: 'image')
    img src=build_path(@page, aspect: 'image', geometry: '640x480>') alt=@page.title
h3= :information.t
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
    tr
      td= :type.t
      td= @type
    tr
      td= :geometry.t
      td= @geometry
    - if @page.version
      tr
        td= :last_modified.t
        td= date @page.version.date
      tr
        td= :version.t
        td.version= @page.version
      tr
        td= :author.t
        td= @page.version.author.name
      tr
        td= :comment.t
        td= @page.version.comment
- unless @exif.empty?
  h3= :exif.t
  table
    thead
      tr
        th= :entry.t
        th= :value.t
    tbody
      - @exif.each do |key, value|
        tr
          td= key
          td= value
@@ locale.yml
cs:
  aspect_imageinfo: 'Informace o obrázku'
  entry: 'Položka'
  exif: 'Informace EXIF'
  geometry: 'Geometrie'
  information: 'Informace'
  type: 'Typ'
  value: 'Hodnota'
de:
  aspect_imageinfo: 'Bild-Information'
  entry: 'Eintrag'
  exif: 'EXIF-Information'
  geometry: 'Geometrie'
  information: 'Information'
  type: 'Typ'
  value: 'Wert'
en:
  aspect_imageinfo: 'Image Information'
  entry: 'Entry'
  exif: 'EXIF Information'
  geometry: 'Geometry'
  information: 'Information'
  type: 'Type'
  value: 'Value'
fr:
  aspect_imageinfo: "Information sur l'image"
  entry: "Entrée"
  exif: "Information EXIF"
  geometry: "Geometrie"
  information: "Information"
  type: "Type"
  value: "Valeur"
