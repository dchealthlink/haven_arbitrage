require 'slack-notifier'
require "nokogiri"
require './config/secret.rb'


class Slack_it

def initialize
@notifier = Slack::Notifier.new SLACK[:webhook_url] do
  defaults channel: SLACK[:channel],
           username: SLACK[:username]
end
end


def get_finapp(ea_xml)
xml = Nokogiri::XML(ea_xml)
faa_id = xml.at("//financial_assistance_application/id/id").content
end


def good_ea_intake(ea_xml)
message = "Received a Payload with Finapp ID: #{get_finapp(ea_xml)}\nIt is a valid XML and processed succesfully"
@notifier.ping message
end

def bad_ea_intake(ea_xml, error_message)
message = "Received a Payload with Finapp ID: #{get_finapp(ea_xml)}\nIt is an Invalid XML\nErrors Found:\n#{error_message}"
@notifier.ping message
end
	

def test
@notifier.ping "Hello default"
end


end
