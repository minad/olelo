# -*- coding: utf-8 -*-
description 'Image aspect'
dependencies 'utils/image_magick'

Aspect.create(:image, priority: 5, accepts: %r{\Aapplication/pdf\Z|postscript\Z|\Aimage/}, cacheable: true) do
  def call(context, page)
    geometry = context.params[:geometry]
    trim = context.params[:trim]
    ps = page.mime.to_s =~ /postscript/
    if ps || page.mime == 'application/pdf'
      page_nr = [context.params[:page].to_i, 1].max
      cmd = ImageMagick.new
      if ps
        cmd.cmd($1 == 'gz' ? 'gunzip' : 'bunzip2') if page.mime.to_s =~ /(bz|gz)/
        cmd.psselect "-p#{page_nr}"
        cmd.gs('-sDEVICE=jpeg', '-sOutputFile=-', '-r144', '-dBATCH', '-dNOPAUSE', '-q', '-')
      end
      cmd.convert('-depth', 8, '-quality', 50) do |args|
        args << '-trim' if trim
        args << '-thumbnail' << geometry if geometry =~ /\A(\d+)?x?(\d+)?[%!<>]*\Z/
        if ps
          args << '-'
        else
          args << '-density' << 144 << "-[#{page_nr - 1}]"
        end
        args << 'JPEG:-'
      end
      context.header['Content-Type'] = 'image/jpeg'
      cmd.run(page.content)
    elsif page.mime.to_s =~ /svg/ || geometry || trim
      cmd = ImageMagick.convert do |args|
        args << '-trim' if trim
        args << '-thumbnail' << geometry if geometry =~ /\A(\d+)?x?(\d+)?[%!<>]*\Z/
        args << '-' << (page.mime.to_s == 'image/jpeg' ? 'JPEG:-' : 'PNG:-')
      end
      context.header['Content-Type'] = 'image/png'
      cmd.run(page.content)
    else
      page.content
    end
  end
end

__END__
@@ locale.yml
cs:
  aspect_image: 'Stažení'
de:
  aspect_image: 'Bild'
en:
  aspect_image: 'Image'
fr:
  aspect_image: "Image"
