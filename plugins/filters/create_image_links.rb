description 'Create links to images'
dependencies 'utils/xml'

Filter.create :create_image_links do |context, content|
  doc = XML::Fragment(content)
  doc.xpath('//img[not(ancestor::a)]').each do |image|
    path = image['src'] || next
    unless path =~ %r{^w+://} || path.starts_with?(build_path('_')) ||
        (path.starts_with?('/') && !path.starts_with?(build_path('')))
      image.swap("<a href=\"#{escape_html path.sub(/\?.*/, '')}\">#{image.to_xhtml}</a>")
    end
  end
  doc.to_xhtml
end
