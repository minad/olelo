# -*- coding: utf-8 -*-
module Olelo
  module BlockHelper
    def blocks
      @blocks ||= Hash.new('')
    end

    def define_block(name, content = nil, &block)
      blocks[name] = block ? block : escape_html(content)
      ''
    end

    def render_block(name)
      block = blocks[name]
      block.respond_to?(:call) ? block.call : block
    end

    def include_block(name)
      wrap_block(name) { render_block(name) }
    end

    def wrap_block(name)
      with_hooks(name) { yield }.join.html_safe
    end
  end

  module FlashHelper
    # Implements bracket accessors for storing and retrieving flash entries.
    class FlashHash
      class << self
        def define_accessors(*accessors)
          accessors.compact.each do |key|
            key = key.to_sym
            class_eval do
              define_method(key) {|*a| a.size > 0 ? (self[key] = a[0]) : self[key] }
              define_method("#{key}=") {|val| self[key] = val }
              define_method("#{key}!") {|val| cache[key] = val }
            end
          end
        end

        def define_set_accessors(*accessors)
          accessors.compact.each do |key|
            key = key.to_sym
            class_eval do
              define_method(key) {|*val| val.size > 0 ? (self[key] ||= Set.new).merge(val) : self[key] }
              define_method("#{key}!") {|*val| val.size > 0 ? (cache[key] ||= Set.new).merge(val) : cache[key] }
            end
          end
        end
      end

      define_set_accessors :error, :warn, :info

      def initialize(session)
        @session = session
        raise 'No session available' if !session
      end

      # Remove an entry from the session and return its value. Cache result in
      # the instance cache.
      def [](key)
        key = key.to_sym
        cache[key] ||= values.delete(key)
      end

      # Store the entry in the session, updating the instance cache as well.
      def []=(key,val)
        key = key.to_sym
        cache[key] = values[key] = val
      end

      # Store a flash entry for only the current request, swept regardless of
      # whether or not it was actually accessed
      def now
        cache
      end

      # Checks for the presence of a flash entry without retrieving or removing
      # it from the cache or store.
      def include?(key)
        key = key.to_sym
        cache.keys.include?(key) || values.keys.include?(key)
      end

      # Clear the hash
      def clear
        cache.clear
        @session.delete(:olelo_flash)
      end

      private

      # Maintain an instance-level cache of retrieved flash entries. These
      # entries will have been removed from the session, but are still available
      # through the cache.
      def cache
        @cache ||= {}
      end

      # Helper to access flash entries from session value. This key
      # is used to prevent collisions with other user-defined session values.
      def values
        @session[:olelo_flash] ||= {}
      end
    end

    include Util

    def flash
      @flash ||= FlashHash.new(env['rack.session'])
    end

    def flash_messages
      li = [:error, :warn, :info].map {|level| flash[level].to_a.map {|msg| %{<li class="#{level}">#{escape_html msg}</li>} } }.flatten
      %{<ul class="flash">#{li.join}</ul>}.html_safe if !li.empty?
    end
  end

  module PageHelper
    include Util

    def include_page(path)
      page = Page.find(path) rescue nil
      if page
        render_page(page)
      else
        %{<a href="#{escape_html build_path(path, action: :new)}">#{escape_html :create_page.t(page: path)}</a>}
      end
    end

    def render_page(page)
      page.content
    end

    def pagination(path, page_count, page_nr, options = {})
      return if page_count <= 1
      unlimited = options.delete(:unlimited)
      li = []
      li << if page_nr > 1
              %{<a href="#{escape_html build_path(path, options.merge(page: page_nr - 1))}">&#9666;</a>}
            else
              %{<span class="disabled">&#9666;</span>}
            end
      min = page_nr - 3
      max = page_nr + 3
      if min > 1
        min -= max - page_count if max > page_count
      else
        max -= min if min < 1
      end
      max = max + 2 < page_count ? max : page_count
      min = min > 3 ? min : 1
      if min != 1
        li << %{<a href="#{escape_html build_path(path, options.merge(page: 1))}">1</a>} << %{<span class="ellipsis"/>}
      end
      (min..max).each do |i|
        li << if i == page_nr
                %{<span class="current">#{i}</span>}
              else
                %{<a href="#{escape_html build_path(path, options.merge(page: i))}">#{i}</a>}
              end
      end
      if max != page_count
        li << %{<span class="ellipsis"/>} << %{<a href="#{escape_html build_path(path, options.merge(page: page_count))}">#{page_count}</a>}
      end
      if page_nr < page_count
        li << %{<span class="ellipsis"/>} if unlimited
        li << %{<a href="#{escape_html build_path(path, options.merge(page: page_nr + 1))}">&#9656;</a>}
      else
        li << %{<span class="disabled">&#9656;</span>}
      end
      ('<ul class="pagination">' + li.map {|x| "<li>#{x}</li>"}.join + '</ul>').html_safe
    end

    def date(t)
      %{<span class="date" data-epoch="#{t.to_i}">#{t.strftime('%d %h %Y %H:%M')}</span>}.html_safe
    end

    def format_diff(diff)
      summary   = PatchSummary.new(links: true)
      formatter = PatchFormatter.new(links: true, header: true)
      PatchParser.parse(diff.patch, summary, formatter)
      (summary.html + formatter.html).html_safe
    end

    def breadcrumbs(page)
      path = page.try(:path) || ''
      li = [%{<li>
<a accesskey="z" href="#{escape_html build_path(nil, version: page)}">#{escape_html :root.t}</a></li>}]
      path.split('/').inject('') do |parent,elem|
        current = parent/elem
        li << %{<li>
<a href="#{escape_html build_path(current, version: page)}">#{escape_html elem}</a></li>}
        current
      end
      ('<ul class="breadcrumbs">' << li.join('<li>/</li>') << '</ul>').html_safe
    end

    def build_path(page, options = {})
      options = options.dup
      action = options.delete(:action)
      version = options.delete(:version)
      path = (page.try(:path) || page).to_s

      if action
        raise ArgumentError if version
        path = action.to_s/path
      else
        version ||= page if Page === page
        version = version.tree_version if Page === version
        path = 'version'/version/path if version && (options.delete(:force_version) || !version.head?)
      end

      unless options.empty?
        query = Rack::Utils.build_query(options)
        path += '?' + query unless query.empty?
      end
      '/' + (Config['base_path'] / path)
    end
  end

  module HttpHelper
    include Util

    def http_accept?(re)
      !env['HTTP_ACCEPT'] || env['HTTP_ACCEPT'] =~ re
    end

    # Cache control for page
    def cache_control(options)
      return if !Config['production']

      if options[:no_cache]
        response.headers.delete('ETag')
        response.headers.delete('Last-Modified')
        response.headers.delete('Cache-Control')
        return
      end

      last_modified = options.delete(:last_modified)
      modified_since = env['HTTP_IF_MODIFIED_SINCE']
      last_modified = last_modified.try(:to_time) || last_modified
      last_modified = last_modified.try(:httpdate) || last_modified

      if User.logged_in?
        # Always private mode if user is logged in
        options[:private] = true

        # Special etag for authenticated user
        options[:etag] = "#{User.current.name}-#{options[:etag]}" if options[:etag]
      end

      if options[:etag]
        value = '"%s"' % options.delete(:etag)
        response['ETag'] = value.to_s
        response['Last-Modified'] = last_modified if last_modified
        if etags = env['HTTP_IF_NONE_MATCH']
          etags = etags.split(/\s*,\s*/)
          # Etag is matching and modification date matches (HTTP Spec §14.26)
          halt :not_modified if (etags.include?(value) || etags.include?('*')) && (!last_modified || last_modified == modified_since)
        end
      elsif last_modified
        # If-Modified-Since is only processed if no etag supplied.
        # If the etag match failed the If-Modified-Since has to be ignored (HTTP Spec §14.26)
        response['Last-Modified'] = last_modified
        halt :not_modified if last_modified == modified_since
      end

      options[:public] = !options[:private]
      options[:max_age] ||= 0
      options[:must_revalidate] ||= true if !options.include?(:must_revalidate)

      response['Cache-Control'] = options.map do |k, v|
        if v == true
          k.to_s.tr('_', '-')
        elsif v
          v = 31536000 if v.to_s == 'static'
          "#{k.to_s.tr('_', '-')}=#{v}"
        end
      end.compact.join(', ')
    end
  end

  module ApplicationHelper
    include BlockHelper
    include FlashHelper
    include PageHelper
    include HttpHelper
    include Templates

    def tabs(*actions)
      tabs = actions.map do |action|
        %{<li id="tabhead-#{action}"#{action?(action) ? ' class="selected"' : ''}><a href="#tab-#{action}">#{escape_html action.t}</a></li>}
      end
      %{<ul class="tabs">#{tabs.join}</ul>}.html_safe
    end

    def action?(action)
      if params[:action]
        params[:action].split('-', 2).first == action.to_s
      else
        unescape(request.path_info).starts_with?("/#{action}")
      end
    end

    def footer(content = nil, &block)
      if block_given? || content
        define_block(:footer, content, &block)
      else
        render_block(:footer)
      end
    end

    def title(content = nil, &block)
      if block_given? || content
        define_block(:title, content, &block)
      else
        render_block(:title)
      end
    end

    def build_static_path(path)
      file = File.join(Config['app_path'], 'static', path)
      build_path "static-#{File.mtime(file).to_i}/#{path}"
    end

    def head
      @@head_links ||= %{<link rel="shortcut icon" href="#{escape_html build_static_path('favicon.png')}" type="image/png"/>
<link rel="stylesheet" href="#{escape_html build_static_path("themes/#{Config['theme']}/style.css")}" type="text/css"/>
<script src="#{escape_html build_static_path("script.js")}" type="text/javascript"></script>}
      # Add base path to root page to fix links in history browsing and for wikis with base_path
      base_path = if request.path_info =~ %r{\A/version/[^/]+\Z} ||
                      (request.path_info == '/' && Config['base_path'] != '/')
        url = request.base_url << [Config['base_path'], '/', request.path_info, '/'].join.gsub(%r{/+}, '/')
        %{<base href="#{escape_html url}"/>}
      end
      [base_path, @@head_links, *invoke_hook(:head)].join.html_safe
    end

    def session
      env['rack.session'] ||= {}
    end

    def menu(name)
      menu = Menu.new(name)
      invoke_hook :menu, menu
      menu.to_html
    end

    alias render_partial render

    def render(name, options = {})
      layout = options.delete(:layout) != false && !params[:no_layout]
      output = Symbol === name ? render_partial(name, options) : name
      output = render_partial(:layout, options) { output } if layout
      invoke_hook :render, name, output, layout
      output
    end
  end
end
