#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def party_from(text)
  if text =~ /(.*?)\s+\((.*?)\)/
    [Regexp.last_match(1), Regexp.last_match(2)]
  else
    raise "No party in #{text}"
  end
end

def scrape_list(url)
  noko = noko_for(url)
  box = noko.css('div#TabbedPanels1 table')[1]
  box.css('a[href*="candidates/"]/@href').map(&:text).uniq.each do |href|
    mp_url = URI.join url, href
    scrape_person(mp_url)
  end
end

def scrape_person(url)
  noko = noko_for(url)
  puts url

  area = noko.xpath('//td[span[contains(.,"Constituency")]]/following-sibling::td').text.tidy
  party, party_id = party_from(noko.xpath('//td[span[contains(.,"Party")]]/following-sibling::td').text.tidy)

  # binding.pry
  headline = noko.css('.news_headline')
  data = {
    id:       url.to_s.split('/').last.sub(/\..*/, ''),
    name:     headline.text.tidy,
    image:    headline.xpath('preceding::img/@src').last.text,
    area:     noko.xpath('//td[span[contains(.,"Constituency")]]/following-sibling::td').text,
    area_id:  'ocd-division/country:vc/constituency:%s' % area.downcase.tr(' ', '-'),
    party:    party,
    party_id: party_id,
    term:     8,
    source:   url.to_s,
  }
  data[:image] = URI.join(url, data[:image]).to_s unless data[:image].to_s.empty?
  ScraperWiki.save_sqlite(%i(id term), data)
end

scrape_list('http://www.caribbeanelections.com/vc/default.asp')
