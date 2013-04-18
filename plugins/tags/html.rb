description 'Safe html tags'

HTML_TAGS = [
  [:a, {optional: %w(href title id)}],
  [:img, {autoclose: true, optional: %w(src alt title id)}],
  [:br, {autoclose: true, optional: %w(id)}],
  [:i, {optional: %w(id)})],
  [:u, {optional: %w(id)})],
  [:b, {optional: %w(id)})],
  [:pre, {optional: %w(id)})],
  [:kbd, {optional: %w(id)})],
  # provided by syntax highlighter
  # [:code, optional: %w(lang)]
  [:cite, {optional: %w(id)})],
  [:strong, {optional: %w(id)})],
  [:em, {optional: %w(id)})],
  [:ins, {optional: %w(id)})],
  [:sup, {optional: %w(id)})],
  [:sub, {optional: %w(id)})],
  [:del, {optional: %w(id)})],
  [:table, {optional: %w(id)})],
  [:tr, {optional: %w(id)})],
  [:td, {optional: %w(colspan rowspan id)}],
  [:th, {optional: %w(id)})],
  [:ol, {optional: %w(start id)}],
  [:ul, {optional: %w(id)})],
  [:li, {optional: %w(id)})],
  [:p, {optional: %w(id)})],
  [:h1, {optional: %w(id)})],
  [:h2, {optional: %w(id)})],
  [:h3, {optional: %w(id)})],
  [:h4, {optional: %w(id)})],
  [:h5, {optional: %w(id)})],
  [:h6, {optional: %w(id)})],
  [:blockquote, {optional: %w(cite id)}],
  [:div, {optional: %w(style id)}],
  [:span, {optional: %w(style id)}],
  [:video, {optional: %w(autoplay controls height width loop preload src poster id)}],
  [:audio, {optional: %w(autoplay controls loop preload src id)}]
]

HTML_TAGS.each do |name, options|
  options ||= {}
  if options.delete(:autoclose)
    Tag.define name, options do |context, attrs|
      attrs = attrs.map {|(k,v)| %{#{k}="#{escape_html v}"} }.join
      "<#{name}#{attrs.blank? ? '' : ' '+attrs}/>"
    end
  else
    Tag.define name, options do |context, attrs, content|
      attrs = attrs.map {|(k,v)| %{#{k}="#{escape_html v}"} }.join
      content = subfilter(context.subcontext, content)
      content.gsub!(/(\A<p[^>]*>)|(<\/p>\Z)/, '')
      "<#{name}#{attrs.blank? ? '' : ' '+attrs}>#{content}</#{name}>"
    end
  end
end
