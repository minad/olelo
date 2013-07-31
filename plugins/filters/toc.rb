# -*- coding: utf-8 -*-
description  'Auto-generated table of contents'
dependencies 'utils/xml'

Page.attributes do
  boolean :toc
end

Filter.create :toc do |context, content|
  return content if !context.page.attributes['toc']

  doc = XML::Fragment(content)
  toc = ''
  level = 0
  count = [0]

  elem = doc.css('h1, h2, h3, h4, h5, h6').first
  offset = elem ? elem.name[1..1].to_i - 1 : 0

  doc.traverse do |child|
    if child.name =~ /\Ah(\d)\Z/
      nr = $1.to_i - offset
      if nr > level
        while nr > level
          toc << (level == 0 ? '<ol class="toc">' : '<ol>')
          count[level] = 0
          level += 1
          toc << '<li>' if nr > level
        end
      else
        while nr < level
          level -= 1
          toc << '</li></ol>'
        end
        toc << '</li>'
      end
      count[level-1] += 1
      headline = child.children.first ? child.children.first.inner_text : ''
      section = ['sec', count[0..level-1], headline.strip.gsub(/[^\w]/, '-')].flatten.join('-').downcase
      toc << %{<li class="toc#{level-offset+1}"><a href="##{section}">#{headline}</a>}
      child.inner_html = %{<span class="number" id="#{section}">#{count[0..level-1].join('.')}</span> #{child.inner_html}}
    end
  end

  while level > 0
    level -= 1
    toc << '</li></ol>'
  end

  toc + doc.to_xhtml
end

__END__
@@ locale.yml
cs:
  attribute_toc: 'Vytvořit obsah'
de:
  attribute_toc: 'Inhaltsverzeichnis erzeugen'
en:
  attribute_toc: 'Generate Table of Contents'
fr:
  attribute_toc: "Générer Table des Matières"
