require 'rest-client'
require 'nokogiri'
require 'json'
require 'logger'
require './app/helpers/publish.rb'

$CURAM_LOG = Logger.new('./log/curam.log', 'monthly')



module EA_Response_builder
extend Publish

#******Getting Haven response using Appref ***********
    def self.call_haven(curam_xml)
    	
    	  curam_res = Nokogiri::XML(curam_xml)
        #{"icNumber" : "xxxxx" } 
        #{"applId":"xxxxxxx"}
        acrn_payload = {"appRefNum" => curam_res.xpath("//AppCaseRef").text}.to_s.gsub("=>", ":")
        ic_payload =   {"icNumber" => curam_res.xpath("//integrated_case_reference").text}.to_s.gsub("=>", ":")
        begin
        puts "calling: enroll_app_system_wrapper"
        haven_response = RestClient.post('newsafehaven.dcmic.org/enroll_app_system_wrapper.php', acrn_payload, {content_type: :"application/json", accept: :"application/json"})
        $CURAM_LOG.info("#{haven_response}")
        
       

         if JSON.parse(haven_response.body).to_h.keys.include?("ACRN Response") 
          puts "calling :  ic_system_wrapper_q3j"
          no_acrn = RestClient.post('newsafehaven.dcmic.org/ic_system_wrapper_q3j.php', ic_payload, {content_type: :"application/json", accept: :"application/json"})
          $CURAM_LOG.info("ACRN not found and Arbitrage triggered ic_system_wrapper_q3j.php webservice. Response: #{no_acrn.body}")
          $CURAM_LOG.info("#{ic_payload}")
        end
        rescue 
          payload = "Error: Unable to get JSON evaluation data set from Haven by calling 
            enroll_app_system_wrapper.php webservice or ic_system_wrapper_q3j.php using Apprefnum: #{ic_payload}"
          email_notice(payload)
          #RestClient.post('newsafehaven.dcmic.org/external_log.php', payload)
          $CURAM_LOG.info("#{payload}")

        end

    end #method


end #module




