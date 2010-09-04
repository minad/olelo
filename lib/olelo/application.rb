module Olelo
  # Main class of the application
  class Application
    include Util
    include Routing
    include Templates
    include ApplicationHelper
    include AttributeEditor

    attribute_editor do
      attribute :title, :string
      attribute :description, :string
      attribute :mime,  :string
    end

    patterns :path => Page::PATH_PATTERN
    attr_reader :logger, :timer, :page
    attr_setter :on_error

    class<< self
      attr_accessor :theme_links
      attr_accessor :reserved_paths

      def reserved_path?(path)
        path = '/' + path.cleanpath
        reserved_paths.any? {|pattern| path =~ pattern }
      end
    end

    def initialize(app = nil, opts = {})
      @app = app
      @logger = opts[:logger] || Logger.new(nil)
      Initializer.init(@logger)
    end

    # Executed before each request
    before :routing do
      @timer = Timer.start

      # Set request ip as progname
      @logger = logger.dup
      logger.progname = request.ip

      logger.debug env

      User.current = User.find(session[:user])
      if !User.current
        invoke_hook(:auto_login)
        User.current ||= User.anonymous(request)
      end

      response['Content-Type'] = 'application/xhtml+xml;charset=utf-8'
    end

    # Executed after each request
    after :routing do
      session[:user] = User.logged_in? ? User.current.name : nil
      User.current = nil
    end

    # Handle 404s
    hook NotFound do |error|
      logger.debug(error)
      cache_control :no_cache => true
      halt render(:not_found, :locals => {:error => error})
    end

    hook StandardError do |error|
      if on_error
        logger.error error
        (error.try(:messages) || [error.message]).each {|msg| flash.error(msg) }
        halt render(on_error)
      end
    end

    # Show wiki error page
    hook Exception do |error|
      logger.error(error)
      cache_control :no_cache => true
      render :error, :locals => {:error => error}
    end

    get '/login' do
      render :login
    end

    post '/login' do
      on_error :login
      User.current = User.authenticate(params[:user], params[:password])
      redirect session.delete(:goto) || '/'
    end

    post '/signup' do
      on_error :login
      User.current = User.create(params[:user], params[:password],
                                 params[:confirm], params[:email])
      redirect '/'
    end

    get '/logout' do
      User.current = nil
      redirect '/'
    end

    get '/profile' do
      raise 'Anonymous users don not have a profile.' if !User.logged_in?
      render :profile
    end

    post '/profile' do
      raise 'Anonymous users don not have a profile.' if !User.logged_in?
      on_error :profile
      User.current.modify do |u|
        u.change_password(params[:oldpassword], params[:password], params[:confirm]) if !params[:password].blank?
        u.email = params[:email]
      end
      flash.info :changes_saved.t
      render :profile
    end

    get '/changes/:version(/:path)' do
      @page = Page.find!(params[:path])
      @version = Version.find!(params[:version])
      @diff = page.diff(nil, @version)
      cache_control :etag => @version, :last_modified => @version.date
      render :changes
    end

    get '/history(/:path)' do
      @page = Page.find!(params[:path])
      @per_page = 30
      @page_nr = params[:page].to_i
      @history = page.history(@page_nr * @per_page)
      @last_page = @page_nr + @history.length / @per_page
      @history = @history[0...@per_page]
      cache_control :etag => page.version, :last_modified => page.version.date
      render :history, :layout => !request.xhr?
    end

    get '/move/:path' do
      @page = Page.find!(params[:path])
      render :move
    end

    get '/delete/:path' do
      @page = Page.find!(params[:path])
      render :delete
    end

    post '/move/:path' do
      @page = Page.find!(params[:path])
      on_error :move
      destination = params[:destination].cleanpath
      raise :reserved_path.t if self.class.reserved_path?(destination)
      Page.transaction(:page_moved.t(:page => page.path, :destination => destination)) do
        page.move(destination)
      end
      redirect absolute_path(page)
    end

    get '/compare/:versions(/:path)', :versions => '(?:\w+)\.{2,3}(?:\w+)' do
      @page = Page.find!(params[:path])
      versions = params[:versions].split(/\.{2,3}/)
      @diff = page.diff(versions.first, versions.last)
      render :compare
    end

    get '/compare(/:path)' do
      versions = params[:versions] || []
      redirect absolute_path(versions.size < 2 ? "#{params[:path]}/history" :
                             "/compare/#{versions.first}...#{versions.last}/#{params[:path]}")
    end

    get '/edit(/:path)' do
      @page = Page.find!(params[:path])
      render :edit
    end

    get '/new(/:path)' do
      @page = Page.new(params[:path])
      flash.error :reserved_path.t if self.class.reserved_path?(page.path)
      params[:path] = !page.root? && Page.find(page.path) ? page.path + '/' : page.path
      render :edit
    end

    def post_edit
      raise 'No content' if !params[:content]
      params[:content].gsub!("\r\n", "\n")
      message = :page_edited.t(:page => page.title)
      message << " - #{params[:comment]}" if !params[:comment].blank?

      Page.transaction(message) do
        page.content = if params[:pos]
                         [page.content[0, params[:pos].to_i].to_s,
                          params[:content],
                          page.content[params[:pos].to_i + params[:len].to_i .. -1]].join
                       else
                         params[:content]
                       end
        redirect absolute_path(page) if @close && !page.modified?
        check do |errors|
          errors << :version_conflict.t if !page.new? && page.version.to_s != params[:version]
          errors << :no_changes.t if !page.modified?
        end
        page.save
      end

      params.delete(:comment)
    end

    def post_upload
      raise 'No file' if !params[:file]
      Page.transaction(:page_uploaded.t(:page => page.title)) do
        raise :version_conflict.t if !page.new? && page.version.to_s != params[:version]
        page.content = params[:file][:tempfile]
        page.save
      end
    end

    def post_attributes
      Page.transaction(:attributes_edited.t(:page => page.title)) do
        page.attributes = parse_attributes
        redirect absolute_path(page) if @close && !page.modified?
        check do |errors|
          errors << :version_conflict.t if !page.new? && page.version.to_s != params[:version]
          errors << :no_changes.t if !page.modified?
        end
        page.save
      end
    end

    def self.final_routes
      get '/version/:version(/:path)|/(:path)' do
        begin
          @page = Page.find!(params[:path], params[:version])
          cache_control :etag => page.version, :last_modified => page.version.date
          @menu_versions = true
          with_hooks :show do
            halt render(:show, :locals => {:content => page.try(:content)})
          end
        rescue NotFound
          if Config.notfound_capitalize && params[:path].to_s != params[:path].to_s.capitalize
            redirect absolute_path(params[:path].to_s.capitalize) if params[:version].blank?
          else
            redirect absolute_path('new'/params[:path].to_s) if params[:version].blank?
          end
          raise
        end
      end

      post '/(:path)' do
        on_error :edit

        @page = Page.find(params[:path]) || Page.new(params[:path])
        raise :reserved_path.t if self.class.reserved_path?(page.path)

        action, @close = params[:action].to_s.split('-')
        if respond_to? "post_#{action}"
          send("post_#{action}")
        else
          raise 'Invalid action'
        end

        flash.info :changes_saved.t
        if @close
          flash.clear
          redirect absolute_path(page)
        else
          render :edit
        end
      end

      delete '/:path' do
        @page = Page.find!(params[:path])
        on_error :delete
        Page.transaction(:page_deleted.t(:page => params[:path].cleanpath)) do
          page.delete
        end
        render :deleted
      end
    end
  end
end
