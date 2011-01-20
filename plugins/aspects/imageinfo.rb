description 'Image information aspect'
dependencies 'utils/image_magick'

Aspect.create(:imageinfo, :priority => 1, :layout => true, :cacheable => true, :accepts => %r{^image/}) do
  def call(context, page)
    @page = page
    identify = ImageMagick.identify('-format', '%m %h %w', '-').run(page.content).split(' ')
    @type = identify[0]
    @geometry = "#{identify[1]}x#{identify[2]}"
    begin
      @exif = Shell.exif('-m', '/dev/stdin').run(page.content)
      @exif.force_encoding(Encoding::UTF_8) if @exif.respond_to? :force_encoding
      @exif = @exif.split("\n").map {|line| line.split("\t") }
      @exif = nil if !@exif[0] || !@exif[0][1]
    rescue => ex
      Olelo.logger.warn "Exif data could not be read: #{ex.message}"
      @exif = nil
    end
    render :info
  end
end

__END__
@@ info.slim
p
  a href=page_path(@page, :aspect => 'image')
    img src=page_path(@page, :aspect => 'image', :geometry => '640x480>') alt=@page.title
h3= :information.t
table
  tbody
    tr
      td= :name.t
      td= @page.name
    tr
      td= :title.t
      td= @page.title
    tr
      td= :description.t
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
- if @exif
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
