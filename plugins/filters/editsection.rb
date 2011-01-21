description 'Adds links for section editing for headlines'

Page.attributes do
  boolean :no_editsection
end

# Supported are
#  * ATX/Markdown style headlines (e.g. ## Headline)
#  * Creole/Mediawiki style headlines (e.g. == Headline)
HEADLINE_STYLE = [
  [%r{^text/x-creole$},  /^([ \t]*(=+)(.*?))=*\s*$/],
  [%r{^text/x-markdown}, /^([ \t\n]*(#+)\s(.*?))#*\s*$/]
]

NestingFilter.create :editsection do |context, content|
  page = context.page
  if context[:preview] || !page.head? || page.attributes['no_editsection']
    subfilter(context, content)
  else
    style = HEADLINE_STYLE.find {|mime,regexp| page.mime.to_s =~ mime }
    raise "Mime type #{page.mime} not supported by editsection filter" if !style
    prefix = "EDIT#{object_id}X"
    len = content.length
    pos, off = [], 0
    while (off = content.index(style.last, off))
      pos << [$2.size, off, off + $1.size, $3.strip]
      off += $&.size
    end
    off = 0
    pos.each_with_index do |p,i|
      link = " #{prefix}#{i} "
      content.insert(p[2] + off, link)
      off += link.size
    end
    content = subfilter(context, content)
    content.gsub!(/#{prefix}(\d+)/) do |match|
      i = $1.to_i
      l = pos[i+1] ? pos[i+1][1] - pos[i][1] - 1 : len - pos[i][1]
      path = action_path(page, :edit) + "?pos=#{pos[i][1]}&len=#{l}&comment=#{:section_edited.t(:section => pos[i][3])}"
      %{<a class="editsection" href="#{escape_html path}" title="#{escape_html :edit_section.t(:section => pos[i][3])}">#{escape_html :edit.t}</a>}
    end
    content
  end
end
