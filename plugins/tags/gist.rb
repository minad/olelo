description    'Tag to embed github gist'
export_scripts 'gist-embed.css'
require 'faraday_middleware'

Tag.define :gist, requires: 'id' do |context, attrs|
  if attrs['id'] =~ /\A\d+\Z/
    conn = Faraday.new 'https://gist.github.com' do |c|
      c.use FaradayMiddleware::ParseJson,       content_type: 'application/json'
      c.use FaradayMiddleware::FollowRedirects
      c.use Faraday::Response::RaiseError
      c.adapter Faraday.default_adapter
    end
    response = conn.get("/#{attrs['id']}.json")
    response.body['div']
  else
    raise ArgumentError, 'Invalid gist id'
  end
end
