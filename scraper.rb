#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_mp(url)
  noko = noko_for(url)
  image = noko.css('div#story img[src*="/cv/"]/@src').text
  image = URI.join(url, image) unless image.to_s.empty?
  {
    name:   noko.css('form#myform h2').text.tidy,
    image:  image.to_s,
    source: url.to_s,
  }
end

def scrape_term(t)
  url = t[:source]
  noko = noko_for(url)
  noko.css('div#story div#story table').first.css('tr').each do |tr|
    tds = tr.css('td')
    mp_page = URI.join url, tds[0].css('a/@href').text
    data = {
      id:        mp_page.to_s[/key=(\w+)/, 1],
      sort_name: tds[0].text.tidy,
      party:     tds[1].text.tidy,
      email:     tds[2].css('a').text.tidy.reverse,
      website:   tds[3].css('a/@href').text,
      term:      t[:id],
    }.merge(scrape_mp(mp_page))
    ScraperWiki.save_sqlite(%i(id term), data)
  end
end

terms = [
  {
    id:         54,
    name:       'Législature 54',
    start_date: '2014',
    source:     'http://www.lachambre.be/kvvcr/showpage.cfm?section=/depute&language=fr&cfm=cvlist54.cfm?legis=54',
  },
]

terms.each do |t|
  scrape_term(t)
end
