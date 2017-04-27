# frozen_string_literal: true
require 'scraped'

class MemberPage < Scraped::HTML
  decorator Scraped::Response::Decorator::AbsoluteUrls

  field :id do
    File.basename(url, '.*')
  end

  field :name do
    name_td.text.delete('*')
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
