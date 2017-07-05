# Using Savon version 1
require 'savon'
#require 'rest-client'
#require 'nokogiri'
require './config/secret.rb'

module Curam_ESB_Service

def self.call(ic)

client = Savon.client do
			wsdl.document = CURAM_ESB_SOAP[:wsdl_url]
			wsse.credentials CURAM_ESB_SOAP[:username], CURAM_ESB_SOAP[:password]
		 end

client.http.auth.ssl.verify_mode = :none
#The name space is changing boy be careful ex: ns1 , v1, WL5G3N3
response = client.request(:WL5G3N3, :process, body: { "WL5G3N3:ICIDParameters" => { "WL5G3N3:IntegratedCasereference_ID" => "#{ic.to_s}" } })
response.to_xml
end	


# def self.haven(ic)
# 	payload = {"icNumber" => "#{ic.to_s}"}.to_s.gsub("=>", ":")
# 	res = RestClient.post('newsafehaven.dcmic.org/enroll_app_system_wrapper.php', payload, {content_type: :"application/xml", accept: :"application/json"})
#     #puts res.body.class
#     doc = Nokogiri::XML res
#     doc.to_xml
# end

end






