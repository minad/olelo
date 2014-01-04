# -*- coding: utf-8 -*-
description 'Newsfeed Aspect'
require 'time'

Aspect.create(:feed, cacheable: true, hidden: true, mime: %r{application/(atom|rss)+xml}) do
  def call(context, page)
    format = context.params[:format]

    url = context.request.base_url
    context.header['Content-Type'] = "application/#{format == 'atom' ? 'atom' : 'rss'}+xml; charset=utf-8"

    per_page = 30
    page_nr = [context.params[:page].to_i, 1].max
    history = page.history((page_nr - 1) * per_page, per_page)

    title = page.root? ? Config['title'] : page.title
    feed = {
      self_link: url + build_path(page, {aspect: 'feed', format: format}.reject{ |k,v| v.blank? }),
      generator: 'Ōlelo',
      title: title,
      description: :feed_description.t(title: title),
      link: url + '/' + page.path,
      date: Time.now,
      author: Config['title'],
      items: []
    }
    history.each do |version|
      feed[:items] << {
        title: version.comment,
        link: "#{url}/changes/#{version}",
        date: version.date,
        author: version.author.name
      }
    end

    render(format == 'atom' ? :feed_atom : :feed_rss, locals: {feed: feed})
  end
end

Application.hook :head do
  render_partial :feed_header
end

__END__
@@ feed_header.slim
link rel="alternate" type="application/atom+xml" title=:sitewide_atom_feed.t href=build_path('/', aspect: 'feed', format: 'atom')
link rel="alternate" type="application/rss+xml" title=:sitewide_rss_feed.t href=build_path('/', aspect: 'feed', format: 'rss')
- if page && !page.new? && !page.root?
  link rel="alternate" type="application/atom+xml" title=:page_atom_feed.t(page: page.path) href=build_path(page.path, aspect: 'feed', format: 'atom')
  link rel="alternate" type="application/rss+xml" title=:page_rss_feed.t(page: page.path) href=build_path(page.path, aspect: 'feed', format: 'rss')
@@ feed_atom.slim
doctype xml
feed xmlns="http://www.w3.org/2005/Atom" xmlns:dc="http://purl.org/dc/elements/1.1/"
  author
    name = feed[:title]
  generator = feed[:generator]
  id = feed[:link]
  link href=feed[:link] /
  link href=feed[:self_link] rel="self" type="application/atom+xml"/
  subtitle = feed[:description]
  title = feed[:title]
  updated = feed[:date].iso8601()
  - feed[:items].each do |item|
    entry
      id = item[:link]
      link href=item[:link] /
      title = item[:title]
      updated = item[:date].iso8601()
      dc:creator = item[:author]
      dc:date = item[:date].iso8601()
@@ feed_rss.slim
doctype xml
rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:dc="http://purl.org/dc/elements/1.1/"
  channel
    title = feed[:title]
    link = feed[:link]
    description = feed[:description]
    pubDate = feed[:date].rfc822()
    atom:link href=feed[:self_link] rel="self" type="application/rss+xml"/
    - feed[:items].each do |item|
      item
        title = item[:title]
        guid = item[:link]
        link = item[:link]
        pubDate = item[:date].rfc822()
        dc:creator = item[:author]
@@ locale.yml
de:
  feed_description:   'Newsfeed für %{title}'
  sitewide_rss_feed:  'RSS-Newsfeed für die ganze Seite'
  sitewide_atom_feed: 'Atom-Newsfeed für die ganze Seite'
  sitewide_rss_feed:  'RSS-Newsfeed für die ganze Seite'
  page_atom_feed:     '%{page} Atom-Newsfeed'
  page_rss_feed:      '%{page} RSS-Newsfeed'
en:
  feed_description:   '%{title} Newsfeed'
  sitewide_atom_feed: 'Sitewide Atom Feed'
  sitewide_rss_feed:  'Sitewide RSS Feed'
  page_atom_feed:     '%{page} Atom Feed'
  page_rss_feed:      '%{page} RSS Feed'
