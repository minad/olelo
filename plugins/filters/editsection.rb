description 'Adds links for section editing for creole-like headlines'

Page.attributes do
  boolean :no_editsection
end

NestingFilter.create :editsection do |context, content|
  if context[:preview] || !context.page.head? || context.page.attributes['no_editsection']
    subfilter(context, content)
  else
    prefix = "EDIT#{object_id}X"
    len = content.length
    pos, off = [], 0
    while (off = content.index(/^([ \t]*([#,=]+)\s(.*?))[#,=]*\s*$/, off))
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
      path = action_path(context.page, :edit) + "?pos=#{pos[i][1]}&len=#{l}&comment=#{:section_edited.t(:section => pos[i][3])}"
      %{<a class="editsection" href="#{escape_html path}" title="#{escape_html :edit_section.t(:section => pos[i][3])}">#{escape_html :edit.t}</a>}
    end
    content
  end
end
