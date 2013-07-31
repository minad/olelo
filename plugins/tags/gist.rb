description    'Tag to embed github gist'
export_scripts 'gist-embed.css'
require 'open-uri'

Tag.define :gist, requires: 'id' do |context, attrs|
  if attrs['id'] =~ /\A\d+\Z/
    body = open("https://gist.github.com/#{attrs['id']}.json").read
    gist = MultiJson.load(body)
    gist['div'].gsub('&nbsp;', '&#8239;')
  else
    raise ArgumentError, 'Invalid gist id'
  end
end
