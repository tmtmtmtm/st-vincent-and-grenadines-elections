#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'
# require 'scraped_page_archive/open-uri'

require_rel 'lib'

def scrape(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

class ResultsPage < Scraped::HTML
  decorator Scraped::Response::Decorator::CleanUrls

  field :elected_members do
    noko.xpath('//span[contains(.,"ELECTED MEMBERS")]//following::table[1]//tr[td]').drop(1).map do |tr|
      fragment tr => WinnerRow
    end
  end
end

class WinnerRow < Scraped::HTML
  field :sort_name do
    tds[2].text.tidy
  end

  field :area do
    tds[0].text.tidy
  end

  field :area_id do
    'ocd-division/country:vc/constituency:%s' % area.downcase.tr(' ', '-')
  end

  field :party do
    tds[3].text.tidy
  end

  field :source do
    # wrong link on site!
    if area == 'South Windward'
      return 'http://www.caribbeanelections.com/vc/election2015/candidates/Frederick_Stephenson.asp'
    end
    tds[2].css('a/@href').text
  end

  private

  def tds
    noko.css('td')
  end
end

start = 'http://www.caribbeanelections.com/vc/elections/vc_results_2015.asp'

data = scrape(start => ResultsPage).elected_members.map do |mem|
  mem.to_h.merge(scrape(mem.source => MemberPage).to_h).merge(term: 9)
end
ata.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
ScraperWiki.save_sqlite(%i(id term), data)
