#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'
require 'scraped_page_archive/open-uri'

# Fix emails in the format:
#   <a class="mail" href="mailto:">eb.remaked@xkyul.retep</a>
class ReversedEmails < Scraped::Response::Decorator
  def body
    Nokogiri::HTML(super).tap do |doc|
      doc.css('a.mail[href*=mailto]').each do |a|
        a[:href] = a.text.empty? ? '' : "mailto:#{a.text.reverse}"
      end
    end.to_s
  end
end

class LaChambre
  class HTML < Scraped::HTML
    decorator ReversedEmails
    decorator Scraped::Response::Decorator::AbsoluteUrls
  end

  class MemberPage < HTML
    field :name do
      noko.css('form#myform h2').text.tidy
    end

    field :image do
      noko.css('div#story img[src*="/cv/"]/@src').text
    end
  end

  class MembersPage < HTML
    field :members do
      noko.css('div#story div#story table').first.css('tr').map do |tr|
        fragment tr => MemberRow
      end
    end
  end

  class MemberRow < Scraped::HTML
    field :id do
      source.to_s[/key=(\w+)/, 1]
    end

    field :sort_name do
      tds[0].text.tidy
    end

    field :email do
      tds[2].css('a/@href').text.gsub('mailto:', '')
    end

    field :website do
      tds[3].css('a/@href').text
    end

    field :source do
      tds[0].css('a/@href').text
    end

    private

    def tds
      noko.css('td')
    end
  end
end

def scrape(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

start = 'http://www.lachambre.be/kvvcr/showpage.cfm?section=/depute&language=fr&cfm=cvlist54.cfm?legis=54&today=%s'
data = scrape(start % 'n' => LaChambre::MembersPage).members.map do |mem|
  mem.to_h.merge(term: 54).merge(scrape(mem.source => LaChambre::MemberPage).to_h)
end
# puts data.map { |r| r.sort_by { |k, _| k }.to_h }

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i[id term], data)
