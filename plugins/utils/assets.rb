description 'Asset manager'

class ::Olelo::Application
  @assets = {}
  @scripts = {}

  class << self
    attr_reader :assets, :scripts
  end

  attr_reader? :disable_assets

  hook :head, 2 do
    render_partial(:assets, locals: {scripts: Application.scripts}) unless disable_assets?
  end

  get "/_/assets(-:version)/assets.:type", type: 'js|css' do
    if script = Application.scripts[params[:type]]
      cache_control max_age: :static, must_revalidate: false, etag: script.first
      response['Content-Type'] = MimeMagic.by_extension(params[:type]).to_s
      response['Content-Length'] = script.last.bytesize.to_s
      script.last
    else
      :not_found
    end
  end

  get "/_/assets(-:version)/:name", name: '.*' do
    if asset = Application.assets[params[:name]]
      fs, name = asset
      cache_control last_modified: fs.mtime(name), max_age: :static, must_revalidate: false
      if path = fs.real_path(name)
        file = Rack::File.new(nil)
        file.path = path
        file.serving(env)
      else
        response['Content-Type'] = (MimeMagic.by_path(name) || 'application/octet-stream').to_s
        response['Content-Length'] = fs.size(name).to_s
        fs.read(name)
      end
    else
      :not_found
    end
  end
end

class ::Olelo::Plugin
  def export_assets(*files)
    virtual_fs.glob(*files) do |fs, name|
      Application.assets[path/name] = [fs, name]
    end
  end

  def export_code(type, code)
    type = type.to_s
    code = [Application.scripts[type].to_a[1], code].compact.join("\n")
    Application.scripts[type] = [md5(Olelo::VERSION + code), code]
  end

  def export_scripts(*files)
    virtual_fs.glob(*files) do |fs, name|
      raise 'Invalid script type' if name !~ /\.(css|js)\Z/
      export_code($1, "/* #{path/name} */\n#{fs.read(name)}\n")
    end
  end
end

__END__
@@ assets.slim
- if scripts['css']
  link rel="stylesheet" type="text/css" href=build_path("_/assets-#{scripts['css'].first}/assets.css")
- if scripts['js']
  script type="text/javascript" src=build_path("_/assets-#{scripts['js'].first}/assets.js")
