# Using Savon version 2
gem 'savon', '=2.11.2'
require 'savon'
require 'nokogiri'
require './config/secret.rb'
require "./app/notifications/slack_notifier.rb"

$CURAM_LOG = Logger.new('./log/curam.log', 'monthly')


module Curam_ESB_Service

def self.call(ic)

savon_config = {
  :wsdl => CURAM_ESB_SOAP[:wsdl_url],
  :ssl_verify_mode => :none,
  :ssl_version => :TLSv1,
  :namespaces => ESB_SERVICE_NAMESPACE,
  :log => true,
  :open_timeout => 300,
  :read_timeout => 300,
  :logger => $CURAM_LOG,
  :wsse_auth => CURAM_ESB_SOAP[:usercredentials]
#   ssl_cert_file: "/home/arbitrage/esb_certs/esb_root.pem",
#   ssl_cert_key_file: "/home/arbitrage/esb_certs/esb_key.pem",
#   ssl_ca_cert_file: "/home/arbitrage/esb_certs/esb_ca.pem"
}

client = Savon.client(savon_config)
#The name space is changing boy be careful ex: ns1 , v1, WL5G3N3
message = { "WL5G3N3:ICIDParameters" => { "WL5G3N3:IntegratedCasereference_ID" => "#{ic.to_s}" } }

begin 
	response = client.call(:process, message: message)
rescue 
	Slack_it.new.notify("IC:#{ic}  No data from curam (500/Timeout/No data). <@mamatha.burujukati>, <@rahulch>, <@venumadhav> :trumpet:")
else
	$CURAM_LOG.info("XML received from curam for IC:#{ic}\n#{Nokogiri::XML(response.xml.to_s).to_xml}")
	response.xml
end #begin end
end	#method end


end







