description  'Basic sidebar implementation'
dependencies 'engine/engine'

class Olelo::Application
  hook :layout do |name, doc|
    page = Page.find(Config.sidebar_page) rescue nil
    doc.css('#sidebar').first << if page
      Cache.cache("sidebar-#{page.version}", :update => request.no_cache?, :defer => true) do |context|
        begin
          Engine.find!(page, :layout => true).output(Context.new(:page => page, :params => {:included => true}))
        rescue Engine::NotAvailable => ex
          %{<span class="error">#{escape_html ex.message}</span>}
        end
      end
    else
      %{<a href="#{escape_html absolute_path('new'/Config.sidebar_page)}">#{escape_html :create_page.t(:page => Config.sidebar_page)}</a>}
    end
  end
end
