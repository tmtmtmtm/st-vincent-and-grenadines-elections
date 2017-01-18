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

class ResultsPage < Scraped::HTML
  decorator Scraped::Response::Decorator::AbsoluteUrls

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
    tds[2].css('a/@href').text
  end

  private

  def tds
    noko.css('td')
  end
end

class MemberPage < Scraped::HTML
  decorator Scraped::Response::Decorator::AbsoluteUrls

  field :id do
    File.basename(url, '.*')
  end

  field :name do
    name_td.text.sub('*', '')
  end

  field :image do
    name_td.xpath('preceding::img[1]/@src').text
  end

  field :party_id do
    party_node.text[/\(([^)]+)\)/, 1]
  end

  private

  def name_td
    noko.css('.Article02')
  end

  def party_node
    name_td.xpath('following::td[.="Party"]//following-sibling::td//a[contains(@href, "/parties/")]')
  end
end

start = 'http://www.caribbeanelections.com/vc/elections/vc_results_2015.asp'

data = scrape(start => ResultsPage).elected_members.map do |mem|
  mem.to_h.merge(scrape(mem.source => MemberPage).to_h).merge(term: 9)
end
# puts data.map { |r| r.sort_by { |k, _| k }.to_h }

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
ScraperWiki.save_sqlite(%i(id term), data)
