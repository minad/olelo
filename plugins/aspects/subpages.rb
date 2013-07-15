# -*- coding: utf-8 -*-
description 'Subpages aspect'

Aspect.create(:subpages, priority: 2, layout: true, cacheable: true) do
  def accepts?(page); !page.children.empty?; end
  def call(context, page)
    @page_nr = [context.params[:page].to_i, 1].max
    per_page = 20
    @page = page
    @page_count = @page.children.size / per_page + 1
    @children = @page.children[((@page_nr - 1) * per_page) ... (@page_nr * per_page)].to_a
    render :subpages
  end
end

__END__
@@ subpages.slim
= pagination(@page, @page_count, @page_nr, aspect: 'subpages')
table#subpages
  thead
    tr
      th= :name.t
      th= :attribute_description.t
      th= :last_modified.t
      th= :author.t
      th= :comment.t
      th= :actions.t
  tbody
    - @children.each do |child|
      - classes = child.children.empty? ? 'page' : 'folder'
      - if !child.extension.empty?
        - classes << " file-type-#{child.extension}"
      tr
        td.link
          a href=build_path(child) class=classes = child.name
        td= truncate(child.attributes['description'], 30)
        td= date(child.version.date)
        td= truncate(child.version.author.name, 30)
        td= truncate(child.version.comment, 30)
        td.actions
          a.action-edit href=build_path(child, action: :edit) title=:edit.t = :edit.t
          a.action-history href=build_path(child, action: :history) title=:history.t = :history.t
          a.action-move href=build_path(child, action: :move) title=:move.t = :move.t
          a.action-delete href=build_path(child, action: :delete) title=:delete.t = :delete.t
= pagination(@page, @page_count, @page_nr, aspect: 'subpages')

@@ locale.yml
cs:
  actions:         'Akce'
  aspect_subpages: 'Podstránky'
  history:         'Historie'
de:
  actions:         'Aktionen'
  aspect_subpages: 'Unterseiten'
  history:         'Historie'
en:
  actions:         'Actions'
  aspect_subpages: 'Subpages'
  history:         'History'
fr:
  actions:         "Actions"
  aspect_subpages: "Sous-pages"
  history:         "Historique"
