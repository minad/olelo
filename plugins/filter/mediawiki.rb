description  'Mediawiki filter'
dependencies 'engine/filter'
require      'wikicloth'

class CustomLinkHandler < WikiCloth::WikiLinkHandler
  def section_link(section)
    # this won't work without a redirect
    # TODO: change wikicloth to include pos, len & page name
    '?edit=' + section.to_s
  end

  def url_for(page)
    page.gsub(/ /, '_')
  end

  def link_attributes_for(page)
     { :href => url_for(page) }
  end

  def include_resource(resource,options=[])
    case resource
    when "date"
      Time.now.to_s
    else
      # default behavior
      super(resource,options)
    end
  end
end

Filter.create :mediawiki do |context, content|
  WikiCloth::WikiCloth.new({
    :data => content,
    :link_handler => CustomLinkHandler.new,
    :params => {},
  }).to_html.gsub('<span class="editsection"', '<span class="editlink"')
end
