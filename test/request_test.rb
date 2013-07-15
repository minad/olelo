require 'helper'
require 'rack/relative_redirect'

class Bacon::Context
  include Rack::Test::Methods
  include Olelo::Util

  attr_reader :app
end

describe 'requests' do
  before do
    @test_path = File.expand_path(File.join(File.dirname(__FILE__), '.test'))
    @app_path = File.expand_path(File.join(File.dirname(__FILE__), '..'))

    default_config = {
      title:             'Olelo',
      app_path:          @app_path,
      plugins_path:      File.join(@app_path, 'plugins'),
      config_path:       File.join(@app_path, 'config'),
      initializers_path: File.join(@app_path, 'config', 'initializers'),
      views_path:        File.join(@app_path, 'views'),
      theme:             'atlantis',
      cache_store:       {
        type: 'HashFile',
        HashFile: {
          dir: File.join(@test_path, 'cache')
        }
      },
      base_path:          '/',
      production:         false,
      locale:             'en_US',
      sidebar_page:       'Sidebar',
      authentication: {
        service:   :yamlfile,
        enable_signup: true,
        yamlfile: {
          store:   File.join(@test_path, 'users.yml'),
        },
      },
      mime: [
                'extension',
                'content',
                'text/x-creole',
               ],
      math_renderer: 'mathjax',
      mime_suggestions: [],
      disabled_plugins: [
                            'security/readonly_wiki',
			    'security/private_wiki',
                            'editor/recaptcha',
                           ],
      repository: {
        type:   'git',
        git: {
          path: File.join(@test_path, 'repository'),
          bare: true,
        },
      }
    }

    Olelo::Config.instance.update(default_config)
    Thread.current[:olelo_repository] = nil

    logger = Logger.new(File.join(@app_path, 'test.log'))
    Olelo::Initializer.initialize(logger)

    @app = Rack::Builder.new do
      use Rack::Session::Pool
      use Rack::MethodOverride
      use Olelo::Middleware::ForceEncoding
      #use Rack::RelativeRedirect
      run Olelo::Application.new
    end
  end

  after do
    FileUtils.rm_rf(@test_path)
  end

  it 'should have empty repository' do
    get '/'
    last_response.should.be.redirect
    last_response.location.should.equal '/new'
  end

  it 'should show login page' do
    get '/login'
    last_response.should.be.ok
    last_response.body.should.include '<form action="/signup" method="post">'
    last_response.body.should.include '<form action="/login" method="post">'
  end

  it 'should show to /new' do
    get '/new/not-existing'
    last_response.should.be.ok
  end

  it 'should redirect to /new' do
    get '/not-existing'
    last_response.should.be.redirect
    last_response.location.should.equal '/new/not-existing'
  end

  it 'should not redirect to /new' do
    get '/edit/not-existing'
    last_response.should.be.not_found

    get '/history/not-existing'
    last_response.should.be.not_found
  end

  it 'should create page' do
    data = {
      'action' => 'edit-close',
      'content' => 'Content of the Testpage',
      'comment' => 'My Comment'
    }
    post '/Testfolder/Testpage', data

    last_response.should.be.redirect
    last_response.location.should.equal '/Testfolder/Testpage'

    get '/'
    last_response.should.be.ok

    get '/Testfolder/Testpage'
    last_response.should.be.ok
    last_response.body.should.include '<h1>Testpage</h1>'
    last_response.body.should.include 'Content of the Testpage'

    get '/history/Testfolder/Testpage'
    last_response.should.be.ok
    last_response.body.should.include 'My Comment'

    get '/edit/Testfolder/Testpage'
    last_response.should.be.ok
  end

  it 'should create page with special characters' do
    data = {
      'action' => 'edit-close',
      'content' => "\343\201\231\343\201\277\343\201\276\343\201\233\343\202\223\343\202\217\343\201\213\343\202\212\343\201\276\343\201\233\343\202\223",
      'comment' => "\346\265\213\350\257\225",
    }
    post '/%E5%AD%90%E4%BE%9B%E3%82%92%E5%85%AC%E5%9C%92/%E4%B8%AD%E6%96%87', data
    last_response.should.be.redirect

    loc1, loc2 = '', ''
    last_response.location.each_byte {|c| loc1 << c}
    unescape('/%E5%AD%90%E4%BE%9B%E3%82%92%E5%85%AC%E5%9C%92/%E4%B8%AD%E6%96%87').each_byte {|c| loc2 << c }
    loc1.should.equal loc2

    get '/%E5%AD%90%E4%BE%9B%E3%82%92%E5%85%AC%E5%9C%92/%E4%B8%AD%E6%96%87'
    last_response.should.be.ok

    get '/history/%E5%AD%90%E4%BE%9B%E3%82%92%E5%85%AC%E5%9C%92/%E4%B8%AD%E6%96%87'
    last_response.should.be.ok

    get '/edit/%E5%AD%90%E4%BE%9B%E3%82%92%E5%85%AC%E5%9C%92/%E4%B8%AD%E6%96%87'
    last_response.should.be.ok
  end
end
