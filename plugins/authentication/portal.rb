description 'Proprietary web portal based user storage'
require 'faraday'

class PortalService < User::Service
  def initialize(config)
    @url = config[:url]
  end

  # @override
  def authenticate(name, password)
    conn = Faraday.new(@url)
    conn.basic_auth(name, password)
    xml = conn.get(@url)
    # User data is exposed via REST/XML-API
    doc = Nokogiri::XML(xml)
    email = (doc/'person/email').text
    name = (doc/'person/user/name').text
    groups = (doc/'person/groups/group/name').to_a.map(&:text)
    raise AuthenticationError if name.blank?
    email = "#{name}@localhost" if email.blank?
    User.new(name, email, groups)
  rescue
    raise AuthenticationError, :wrong_user_or_pw.t
  end
end

User::Service.register :portal, PortalService
