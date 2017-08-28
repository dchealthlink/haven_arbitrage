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
xml.remove_namespaces! 
begin 
faa_id = xml.at("//financial_assistance_application/id/id").content
# The following if condition is just for an extra caution to just get the Finadd ID instead of any extra data
	if faa_id.include?("\n")
		return faa_id.split(/\n/).first
	else
		return faa_id
	end
rescue => error
	puts "get_finapp: #{error.message}"
end

end


def good_ea_intake(ea_xml)
message = "Received a Payload with Finapp ID: #{get_finapp(ea_xml)}\nIt is a valid XML\n"
@notifier.ping message
end

def bad_ea_intake(ea_xml, error_message)
message = "Received a Payload with Finapp ID: #{get_finapp(ea_xml)}\nIt is an Invalid XML\nErrors Found:\n#{error_message}"
@notifier.ping message
end


def notify(message)
@notifier.ping message
end


end
