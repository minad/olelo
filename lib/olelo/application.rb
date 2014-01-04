module Olelo
  # Main class of the application
  class Application
    include Util
    include Hooks
    include ErrorHandler
    include Routing
    include ApplicationHelper

    patterns path: Page::PATH_PATTERN
    attr_reader :page
    attr_setter :on_error

    has_around_hooks :routing, :action, :login_buttons,
                     :edit_buttons, :attributes_buttons, :upload_buttons
    has_hooks :auto_login, :render, :menu, :head

    def self.reserved_path?(path)
      path = '/' + path.cleanpath
      path.starts_with?('/static') ||
      router.any? do |method, r|
        r.any? do |name,pattern,keys,function|
          name !~ /\A\/\(?:path\)?\Z/ && pattern.match(path)
        end
      end
    end

    def initialize(app = nil)
      @app = app
    end

    # Executed before each request
    before :routing do
      User.current = User.find(session[:olelo_user])
      unless User.current
        invoke_hook(:auto_login)
        User.current ||= User.anonymous(request)
      end

      response['Content-Type'] = 'text/html;charset=utf-8'
    end

    # Executed after each request
    after :routing do
      if User.logged_in?
        session[:olelo_user] = User.current.name
      else
        session.delete(:olelo_user)
      end
      User.current = nil
    end

    hook :menu do |menu|
      if menu.name == :actions && page && !page.new?
        menu.item(:view, href: build_path(page.path), accesskey: 'v')
        edit_menu = menu.item(:edit, href: build_path(page, action: :edit), accesskey: 'e', rel: 'nofollow')
        edit_menu.item(:new, href: build_path(page, action: :new), accesskey: 'n', rel: 'nofollow')
        if !page.root?
          edit_menu.item(:move, href: build_path(page, action: :move), rel: 'nofollow')
          edit_menu.item(:delete, href: build_path(page, action: :delete), rel: 'nofollow')
        end
      end
    end

    # Handle 404s
    error NotFound do |error|
      Olelo.logger.debug(error)
      if http_accept? /html/
        cache_control no_cache: true
        halt render(:not_found, locals: {error: error})
      else
        halt :not_found
      end
    end

    error StandardError do |error|
      Olelo.logger.error error
      if on_error && http_accept? /html/
        (error.try(:messages) || [error.message]).each {|msg| flash.error!(msg) }
        halt render(on_error)
      end
    end

    # Show wiki error page
    error Exception do |error|
      Olelo.logger.error(error)
      if http_accept? /html/
        cache_control no_cache: true
        halt render(:error, locals: {error: error})
      end
    end

    get '/login' do
      session[:olelo_goto] ||= env['HTTP_REFERER']
      render :login
    end

    post '/login' do
      on_error :login
      User.current = User.authenticate(params[:user], params[:password])
      redirect(session.delete(:olelo_goto) || build_path('/'))
    end

    post '/signup' do
      on_error :login
      raise 'Sign-up is disabled' if !Config['authentication.enable_signup']
      User.current = User.signup(params[:user], params[:password],
                                 params[:confirm], params[:email])
      redirect(session.delete(:olelo_goto) || build_path('/'))
    end

    get '/logout' do
      User.current = User.anonymous(request)
      redirect(env['HTTP_REFERER'] || build_path('/'))
    end

    get '/profile' do
      raise 'Anonymous users do not have a profile.' if !User.logged_in?
      render :profile
    end

    post '/profile' do
      raise 'Anonymous users do not have a profile.' if !User.logged_in?
      on_error :profile
      if User.supports?(:change_password) && !params[:password].blank?
        User.current.change_password(params[:oldpassword], params[:password], params[:confirm])
      end
      if User.supports?(:update)
        User.current.update do |u|
          u.email = params[:email]
        end
      end
      flash.info! :changes_saved.t
      render :profile
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
      Page.transaction do
        @page = Page.find!(params[:path])
        on_error :move
        destination = params[:destination].cleanpath
        raise :reserved_path.t if self.class.reserved_path?(destination)
        page.move(destination)
        Page.commit(:page_moved.t(page: page.path, destination: destination))
        redirect build_path(page.path)
      end
    end

    get '/edit(/(:path))' do
      @page = Page.find!(params[:path])
      flash.info!(:info_binary.t(page: page.title, type: "#{page.mime.comment} (#{page.mime})")) unless page.editable?
      render :edit
    end

    get '/new(/(:path))' do
      @page = Page.new(params[:path])
      flash.error! :reserved_path.t if self.class.reserved_path?(page.path)
      params[:path] = !page.root? && Page.find(page.path) ? page.path + '/' : page.path
      render :edit
    end

    def post_edit
      raise 'No content' if !params[:content]
      params[:content].gsub!("\r\n", "\n")
      message = :page_edited.t(page: page.title)
      message << " - #{params[:comment]}" if !params[:comment].blank?

      page.content = if params[:pos]
                       [page.content[0, params[:pos].to_i].to_s,
                        params[:content],
                        page.content[params[:pos].to_i + params[:len].to_i .. -1]].join
                     else
                       params[:content]
                     end
      redirect build_path(page.path) if @close && !page.modified?
      check do |errors|
        errors << :version_conflict.t if !page.new? && page.version.to_s != params[:version]
        errors << :no_changes.t if !page.modified?
      end
      page.save

      Page.commit(message)
      params.delete(:comment)
    end

    def post_upload
      raise 'No file' if !params[:file]
      page.content = params[:file][:tempfile].read
      check do |errors|
        errors << :version_conflict.t if !page.new? && page.version.to_s != params[:version]
        errors << :no_changes.t if !page.modified?
      end
      page.save
      Page.commit(:page_uploaded.t(page: page.title))
    end

    def post_attributes
      page.update_attributes(params)
      redirect build_path(page.path) if @close && !page.modified?
      check do |errors|
        errors << :version_conflict.t if !page.new? && page.version.to_s != params[:version]
        errors << :no_changes.t if !page.modified?
      end
      page.save
      Page.commit(:attributes_edited.t(page: page.title))
    end

    get '/(:path)', tail: true do
      begin
        @page = Page.find!(params[:path])
        cache_control etag: page.etag
        show_page
      rescue NotFound
        raise unless http_accept?(/html/)
        redirect build_path(params[:path], action: :new)
      end
    end

    get '/version/:version(/(:path))' do
      @page = Page.find!(params[:path], params[:version])
      cache_control etag: page.etag
      show_page
    end

    post '/(:path)', tail: true do
      action, @close = params[:action].to_s.split('-', 2)
      if respond_to? "post_#{action}"
        on_error :edit
        Page.transaction do
          @page = Page.find(params[:path]) || Page.new(params[:path])
          raise :reserved_path.t if self.class.reserved_path?(page.path)
          send("post_#{action}")
        end
      else
        raise 'Invalid action'
      end

      if @close
        flash.clear
        redirect build_path(page.path)
      else
        flash.info! :changes_saved.t
        render :edit
      end
    end

    delete '/:path', tail: true do
      Page.transaction do
        @page = Page.find!(params[:path])
          on_error :delete
        page.delete
        Page.commit(:page_deleted.t(page: page.path))
        render :deleted
      end
    end
  end
end
