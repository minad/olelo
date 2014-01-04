description    'Gallery aspect'
dependencies   'utils/assets', 'aspects'
export_scripts '*.css'

Aspects::Aspect.create(:gallery, priority: 3, hidden: true, cacheable: true) do
  def accepts?(page); !page.children.empty?; end
  def call(context, page)
    @per_row = 4
    per_page = @per_row * 4
    @page_nr = [context.params[:page].to_i, 1].max
    @page = page
    @images = @page.children.select {|p| p.mime.image? }
    @page_count = @images.size / per_page + 1
    @images = @images[((@page_nr - 1) * per_page) ... (@page_nr * per_page)].to_a
    render :gallery
  end
end

__END__
@@ gallery.slim
= pagination(@page, @page_count, @page_nr, aspect: 'gallery')
table.gallery
  - @images.each_slice(@per_row) do |row|
    tr
      - row.each do |image|
        ruby:
          thumb_path = build_path(image, aspect: 'image', geometry: '150x150>')
          info_path  = build_path(image)
          description = image.attributes['description'] || image.attributes['title'] || \
            image.name.gsub(/([^\s])[_\-]/, '\1 ')
        td
          a.fancybox href=info_path rel="gallery" title=description
            img src=thumb_path alt=''
          a.title href=info_path = description
@@ locale.yml
cs:
  aspect_gallery: 'Galerie'
de:
  aspect_gallery: 'Bildergalerie'
en:
  aspect_gallery: 'Image Gallery'
fr:
  aspect_gallery: "Galerie d'images"
