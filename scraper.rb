#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'scraped'
require 'scraperwiki'
require 'pry'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def scrape(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

class MembersPage < Scraped::HTML
  decorator Scraped::Response::Decorator::AbsoluteUrls

  field :member_urls do
    box = noko.css('div#TabbedPanels1 table')[1]
    box.css('a[href*="candidates/"]/@href').map(&:text).uniq
  end
end

class MemberPage < Scraped::HTML
  decorator Scraped::Response::Decorator::AbsoluteUrls

  field :id do
    url.to_s.split('/').last.sub(/\..*/, '')
  end

  field :name do
    headline.text.tidy
  end

  field :image do
    headline.xpath('preceding::img/@src').last.text
  end

  field :area do
    noko.xpath('//td[span[contains(.,"Constituency")]]/following-sibling::td').text.strip
  end

  field :area_id do
    'ocd-division/country:vc/constituency:%s' % area.downcase.tr(' ', '-')
  end

  field :party do
    party_data.first
  end

  field :party_id do
    party_data.last
  end

  field :source do
    url.to_s
  end

  private

  def headline
    noko.css('.news_headline')
  end

  def area
    noko.xpath('//td[span[contains(.,"Constituency")]]/following-sibling::td').text.tidy
  end

  def party_data
    party_from(noko.xpath('//td[span[contains(.,"Party")]]/following-sibling::td').text.tidy)
  end

  def party_from(text)
    if text =~ /(.*?)\s+\((.*?)\)/
      [Regexp.last_match(1), Regexp.last_match(2)]
    else
      raise "No party in #{text}"
    end
  end
end

start = 'http://www.caribbeanelections.com/vc/default.asp'

data = scrape(start => MembersPage).member_urls.map do |url|
  scrape(url => MemberPage).to_h.merge(term: 8)
end
# puts data.map { |r| r.sort_by { |k, _| k }.to_h }

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
ScraperWiki.save_sqlite(%i(id term), data)
