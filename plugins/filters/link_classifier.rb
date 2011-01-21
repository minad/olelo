description  'Classify links as absent/present/external'
dependencies 'utils/xml'

Filter.create :link_classifier do |context, content|
  doc = XML::Fragment(content)
  doc.css('a[href]').each do |link|
    href =  link['href']
    classes = [link['class']].compact
    if href.starts_with?('http://') || href.starts_with?('https://')
      classes << 'external'
    elsif !href.empty? && !href.starts_with?('#')
      path, query = href.split('?')
      if path.starts_with? Config['base_path']
        path = path[Config['base_path'].length-1..-1]
      elsif !path.starts_with? '/'
        path = context.page.path/'..'/path
      end
      classes << 'internal'
      if !Application.reserved_path?(path)
        classes << (Page.find(path, context.page.tree_version) ? 'present' : 'absent') rescue nil
      end
    end
    link['class'] = classes.join(' ') if !classes.empty?
  end
  doc.to_xhtml
end
