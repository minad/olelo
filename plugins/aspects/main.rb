# -*- coding: utf-8 -*-
description 'Aspect subsystem'
dependencies 'utils/cache'

Page.attributes do
  enum :aspect do
    Aspect.aspects.keys.inject({}) do |hash, name|
      hash[name] = Locale.translate("aspect_#{name}", fallback: titlecase(name))
      hash
    end
  end
end

# Aspect context
# A aspect context holds the request parameters and other
# variables used by the aspects.
# It is possible for a aspect to run sub-aspects. For this
# purpose you create a subcontext which inherits the variables.
class Context
  include Hooks
  has_hooks :initialized

  attr_reader :page, :private, :params, :request, :header

  def initialize(options = {})
    @page     = options[:page]
    @private  = options[:private]  || Hash.with_indifferent_access
    @params   = Hash.with_indifferent_access.merge(options[:params] || {})
    @request  = options[:request]
    @header   = options[:header] || Hash.with_indifferent_access
    invoke_hook(:initialized)
  end

  def [](key)
    private[key]
  end

  def []=(key, value)
    private[key] = value
  end

  def subcontext(options = {})
    Context.new(page:    options[:page] || page,
                private: private.merge(options[:private] || {}),
                params:  params.merge(options[:params] || {}),
                request: request,
                header:  header)
  end
end

# An Aspect renders pages
# Aspects get a page as input and create text.
class Aspect
  include PageHelper
  include Templates

  @aspects = {}

  class NotAvailable < NameError
    def initialize(name, page)
      super(:aspect_not_available.t(aspect: name, page: page.path,
                                    type: "#{page.mime.comment} (#{page.mime})"))
    end

    def status
      :bad_request
    end
  end

  FRAGMENT_MIME = 'text/x-html-fragment'

  # Constructor for aspect
  # Options:
  # * priority: Aspect priority. The aspect with the lowest priority will be used for a page.
  # * cacheable: Aspect is cacheable
  def initialize(name, options)
    @name        = name.to_s
    @hidden      = !!options[:hidden]
    @cacheable   = !!options[:cacheable]
    @priority    = (options[:priority] || 99).to_i
    @accepts     = Regexp === options[:accepts] ? options[:accepts] : /\A(?:#{options[:accepts]})\Z/
    @mime        = options.include?(:mime) ? options[:mime] : FRAGMENT_MIME
    @plugin      = options[:plugin] || Plugin.for(self.class)
    @description = options[:description] || @plugin.description
  end

  attr_reader :name, :priority, :mime, :accepts, :description, :plugin
  attr_reader? :hidden, :cacheable

  def layout?
    mime == FRAGMENT_MIME
  end

  # Aspects hash
  def self.aspects
    @aspects
  end

  # Create aspect class. This is sugar to create and
  # register an aspect class in one step.
  def self.create(name, options = {}, &block)
    options[:plugin] ||= Plugin.for(block)
    klass = Class.new(self)
    klass.class_eval(&block)
    register klass.new(name, options)
  end

  # Register aspect instance
  def self.register(aspect)
    (@aspects[aspect.name] ||= []) << aspect
  end

  # Find all accepting aspects for a page
  def self.find_all(page)
    @aspects.values.map do |aspects|
      aspects.sort_by(&:priority).find {|a| a.accepts?(page) }
    end.compact
  end

  # Find appropiate aspect for page. An optional
  # name can be given to claim a specific aspect.
  # If no aspect is found a exception is raised.
  def self.find!(page, options = {})
    options[:name] ||= page.attributes['aspect']
    aspects = options[:name] ? @aspects[options[:name].to_s] : @aspects.values.flatten
    aspects = aspects.to_a.sort_by(&:priority).select {|a| a.accepts?(page) && (!options[:layout] || a.layout?) }

    puts "PREF #{options[:preferred_mime]}"


    aspect = (options[:preferred_mime] && aspects.find {|a| a.mime.include?(options[:preferred_mime]) }) || aspects.first
    raise NotAvailable.new(options[:name], page) if !aspect
    aspect.dup
  end

  # Find appropiate aspect for page. An optional
  # name can be given to claim a specific aspect.
  # If no aspect is found nil is returned.
  def self.find(page, options = {})
    find!(page, options) rescue nil
  end

  # Acceptor should return true if page would be accepted by this aspect.
  # Reimplement this method.
  def accepts?(page)
    !@accepts || page.mime.to_s =~ @accepts
  end

  # Render page content.
  # Reimplement this method.
  def call(context, page)
    raise NotImplementedError
  end
end

# Plug-in the aspect subsystem
module ::Olelo::PageHelper
  def render_page(page)
    cache(['include', page.path, page.etag], update: no_cache?, defer: true) do
      begin
        context = Context.new(page: page, params: {included: true})
        Aspect.find!(page, layout: true).call(context, page)
      rescue Aspect::NotAvailable => ex
        %{<span class="error">#{escape_html ex.message}</span>}
      end
    end
  end
end

# Plug-in the aspect subsystem
class ::Olelo::Application
  def show_page
    params[:aspect] ||= 'subpages' if params[:path].to_s.ends_with? '/'

    env['HTTP_ACCEPT'].to_s =~ %r{[\w\.\+\-\*]+/[\*\w\.\+\-]+}
    preferred_mime = $&

    @selected_aspect, cacheable, layout, header, content =
    cache(['aspect', page.path, page.etag, params, preferred_mime], update: no_cache?, defer: true) do |cache|
      aspect = Aspect.find!(page, name: params[:aspect], preferred_mime: preferred_mime)
      cache.disable! if !aspect.cacheable?
      context = Context.new(page: page, params: params, request: request)
      context.header['Content-Type'] = aspect.mime ? aspect.mime.to_s : page.mime.to_s unless aspect.layout?
      result = aspect.call(context, page)
      [aspect.name, aspect.cacheable?, aspect.layout?, context.header.to_hash, result]
    end

    if cacheable
      response['Vary'] = 'Accept'
    else
      cache_control no_cache: true
    end

    self.response.header.merge!(header)

    layout ? render(:show, locals: {content: content}) : content
  rescue Aspect::NotAvailable => ex
    cache_control no_cache: true
    raise unless http_accept? /html/
    redirect build_path(page.path) if params[:path].to_s.ends_with? '/'
    raise if params[:aspect]
    flash.error ex.message
    redirect build_path(page, action: :edit)
  end

  hook :menu do |menu|
    if menu.name == :actions && view_menu = menu[:view]
      view_menu.append(cache(['aspect-menu', page.path, page.etag, @selected_aspect], update: no_cache?, defer: true) do
        aspects = Aspect.find_all(page).select {|a| !a.hidden? || a.name == @selected_aspect || a.name == page.attributes['aspect'] }.map do |a|
          [Locale.translate("aspect_#{a.name}", fallback: titlecase(a.name)), a]
        end.sort_by(&:first)
        aspects.select {|label, a| a.layout? }.map do |label, a|
          MenuItem.new(a.name, label: label, href: build_path(page, aspect: a.name), class: a.name == @selected_aspect ? 'selected' : nil)
        end +
        aspects.reject {|label, a| a.layout? }.map do |label, a|
          MenuItem.new(a.name, label: label, href: build_path(page, aspect: a.name), class: 'download')
        end
      end)
    end
  end

  redefine_method :footer do |content = nil, &block|
    # FIXME: Use block instead of block_given?, block_given? returns always false. Is this a ruby issue?
    if block || content
      super(content, &block)
    elsif page
      cache(['footer', page.path, page.etag], update: no_cache?) { super() }
    else
      super()
    end
  end
end

__END__
@@ locale.yml
cs:
  aspect_not_available: 'Vzhled %{aspect} není k dispozici pro stránku %{page} s typem %{type}.'
  attribute_aspect: 'Přednastavený vzhled'
de:
  aspect_not_available: 'Aspekt %{aspect} für die Seite %{page} mit dem Typ %{type} ist nicht verfügbar.'
  attribute_aspect: 'Standard-Ansicht'
en:
  aspect_not_available: 'Aspect %{aspect} is not available for page %{page} with type %{type}.'
  attribute_aspect: 'Default Aspect'
fr:
  aspect_not_available: "L'aspect %{aspect} n'est pas disponible pour la page %{page} avec le type %{type}."
  attribute_aspect: "Aspect par défaut"
