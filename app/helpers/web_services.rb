# Using Savon version 1
require 'savon'
require 'rest-client'
require 'nokogiri'
require './config/secret.rb'

module Web_Services

def self.curam(ic)
client = Savon.client(WEB_SERVICES_URL[:curam])
#client.config.pretty_print_xml = true
response = client.request :ns1, :process, body: { "ns1:ICIDParameters" => { "ns1:IntegratedCasereference_ID" => "#{ic}" } }
end	


def self.haven(ic)
	payload = {"icNumber" => "#{ic.to_s}"}.to_s.gsub("=>", ":")
	res = RestClient.post('newsafehaven.dcmic.org/enroll_app_system_wrapper.php', payload, {content_type: :"application/xml", accept: :"application/json"})
    #puts res.body.class
    doc = Nokogiri::XML res
    doc.to_xml
end

end

#Web_Services.curam("xxxxxx")




