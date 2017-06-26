require 'rest-client'
require 'nokogiri'
require 'json'
require 'logger'
require './app/helpers/publish.rb'

$LOG = Logger.new('./log/log_file.log', 'monthly')



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
        haven_response = RestClient.post('newsafehaven.dcmic.org/enroll_app_system_wrapper.php', ic_payload, {content_type: :"application/json", accept: :"application/json"})
        $LOG.info("#{haven_response}")
        
       

         if JSON.parse(haven_response.body).to_h.keys.include?("ACRN Response") 
          puts "calling :  ic_system_wrapper_q3j"
          no_acrn = RestClient.post('newsafehaven.dcmic.org/ic_system_wrapper_q3j.php', ic_payload, {content_type: :"application/json", accept: :"application/json"})
          $LOG.info("ACRN not found and Arbitrage triggered ic_system_wrapper_q3j.php webservice. Response: #{no_acrn.body}")
          $LOG.info("#{ic_payload}")
        #else
        #curam_xml_template = self.build_response(haven_response)
        #self.post_status_log(haven_response, curam_xml_template)
        #curam_xml_template
        end
        rescue 
          payload = "Error: Unable to get JSON evaluation data set from Haven by calling 
            enroll_app_system_wrapper.php webservice or ic_system_wrapper_q3j.php using Apprefnum: #{ic_payload}"
          email_notice(payload)
          RestClient.post('newsafehaven.dcmic.org/external_log.php', payload)
          $LOG.info("#{payload}")

        end

    end



#puts haven

# def haven_ext_log(payload)
#    RestClient.post('newsafehaven.dcmic.org/external_log.php', payload)
# end


#********Status code ***************

def self.post_status_log(haven_json, curam_template)

haven_res = JSON.parse(haven_json)
#curam_xml = Nokogiri::XML(curam_template)
curam_xml = %Q{"#{curam_template}"}
curam_xml.slice!("<?xml version=\"1.0\" standalone=\"yes\"?>")

$LOG.info("#{"*"*100}\nThe class is: #{haven_res.class}\n#{curam_xml}\n#{"*"*100}\n")

json_status_payload = {

	"applid" => haven_res["applid"],  
	"status" => "SUCCESS",  
	"requesttype" => "RECEIVED", 
	"apprefnum" => haven_res["apprefnum"], 
  "type" => "ARBITRAGE",
  "queuename" => "N/A",
  "jsonpayload" => haven_res.to_s.gsub!(/\"/, '\'')
	}.to_s.gsub("=>", ":")

$LOG.info("#{json_status_payload}")
res = RestClient.post('newsafehaven.dcmic.org/external_log.php', json_status_payload, {content_type: :"application/json", accept: :"application/json"})
$LOG.info("#{res.body}")


xml_status_payload = {

  "applid" => haven_res["applid"],  
  "status" => "SUCCESS",  
  "requesttype" => "SENT", 
  "apprefnum" => haven_res["apprefnum"], 
  "type" => "ARBITRAGE",
  "queuename" => "HavenICPayload_Request_RMQ",
  "payload" => curam_xml.gsub("\n",'')

  }.to_s.gsub("=>", ":")

$LOG.info("#{xml_status_payload}")
res = RestClient.post('newsafehaven.dcmic.org/external_log.php', xml_status_payload, {content_type: :"application/xml", accept: :"application/json"})
$LOG.info("#{res.body}")
end





def self.build_response(res)

  

 haven_res = JSON.parse(res)

xml = Nokogiri::XML('<?xml version = "1.0" standalone ="yes"?>')
builder = Nokogiri::XML::Builder.with(xml) do |xml|

  xml.integrated_cases( 'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance") {
    xml.integrated_case {
      xml.integrated_case_reference haven_res["icnumber"]
      xml.application_submission_date haven_res["postdate"] #It is Post date
      #xml.application_reference "xxxxxx" # We don't need this to send EA
      xml.curam_applicants {

        haven_res["Person"].each do |person| #iterating persons
            xml.curam_applicant {
              
              xml.identifier_sets {
                xml.identifier_set {
                  xml.participant_id ""
                  xml.aceds_id "xxxxxx" #"#{haven_res.xpath("//aceds_id").first.text}"
                } # identifier set close 
              } #identifier sets close
           
           xml.concern_role_id person["personid"]
           xml.full_name person["personfirstname"] + " " + person["personlastname"]
           xml.is_primary_applicant "" #true ask tom
           xml.date_of_birth person["persondob"]
           xml.age ""   #ask Tom
           xml.gender person["gender"]
           xml.ssn person["personssn"]
               xml.allocated_aptcs {
                 xml.allocated_aptc {
                  xml.aptc_amount ""
                    xml.aptc_start_date ""
                    xml.aptc_created_on ""
                 } #allocated_aptc
               } #allocated aptcs
           xml.aptc_amount ""
           xml.aptc_start_date ""
           xml.aptc_created_on ""

           xml.csr ""
           xml.is_resident person["isstateresident"]
           xml.is_applicant person["isapplicant"]
           xml.citizen_status person["citizen_status"] 
           
             haven_res["TaxHousehold"].each do |th|         
                xml.tax_filing_status th["filer_type"] if th["personid"] == person["personid"]
             end
           xml.tax_filing_together "" #false boolean value ask tom
           xml.tax_dependents ""
           xml.incarceration_status person["isincarcerated"]
           xml.household_size "" #ask tom

           xml.incomes {
            if person["Income"] != nil
            person["Income"].each do |income|
              xml.income {
                xml.amount income["incomeamount"]
                  xml.frequency income["paymentfrequency"]
                  xml.income_type income["incometype"]
                  xml.start_date "" #no info ask tom
                  xml.end_date "" #no info ask tom
              } end# income
            else 
              xml.income {
                xml.amount ""
                  xml.frequency ""
                  xml.income_type ""
                  xml.start_date "" #no info ask tom
                  xml.end_date "" #no info ask tom
              }
            end
            } #incomes 

            xml.benefits {
              xml.benefit {
            xml.type ""
                  xml.start_date ""
                  xml.end_date ""
              } #benefit
            
            } # benefits

            xml.deductions {
              xml.deduction {
                xml.type ""
                  xml.amount ""
                  xml.frequency ""
                  xml.start_date ""
                  xml.end_date ""
              } #deduction

            } # deductions

            xml.address {

              xml.address_line_1 ""
              xml.address_line_2 ""
              xml.address_line_3 "" 
              xml.city ""
              xml.county ""
              xml.state ""
              xml.postal_code ""
            } # address

            xml.email_address ""

            xml.telephone_number {
              xml.country_code ""
                xml.area_code ""
                xml.number ""
                xml.number_full ""
            } # telephone number

            
        xml.relationships { 
          if haven_res["ApplicationRelationship"] != nil
        haven_res["ApplicationRelationship"].each do |relationship|
          xml.relationship {
            xml.relationship_type relationship["relationship"] if relationship["personid"] == person["personid"]
            xml.related_participant_id relationship["cross_personid"] if relationship["personid"] == person["personid"]
          } 
        end
          else
            xml.relationship {
            xml.relationship_type ""
            xml.related_participant_id ""
          }
          end# relationship
          } # relationships

        xml.created_at ""
            xml.modified_at ""
     
          } #applicant set close
  end
     } #applicants set close
     
    
    xml.brokers ""

    xml.product_delivery_cases {
      haven_res["PDC"].each do |pdc|
      xml.product_delivery_case {
        xml.pdc_case_reference pdc["haven_pdc"]
          xml.pdc_product_type pdc["haven_code"]
          xml.pdc_product_type_description pdc["producttype"]
          xml.pdc_primary_applicant_name ""
          xml.pdc_primary_applicant_id ""
          xml.pdc_primary_applicant_concern_role_id ""

          
          xml.pdc_applicants {
            if pdc["Person"] != nil
            pdc["Person"].each do |pdc_person|
            xml.pdc_applicant {
              xml.participant_id ""
                xml.concern_role_id pdc_person["haven_personid"]
                    xml.applicant_name pdc_person["consentname"]
                xml.consent_applicant pdc_person["consentname"]
                xml.is_enrolled_for_es_coverage ""
                xml.is_without_assistance ""
                xml.years_to_renew_coverage ""
                xml.financial_assistance ""
                xml.ia_eligible ""
                xml.medicaid_chip_eligible ""
                xml.receiving_benefit ""
                xml.projected_amount ""
                xml.participant_projected_income ""
                xml.projected_income_start_date ""
                xml.projected_income_end_date ""
                xml.application_submission_date ""
            } #pdc_applicant
              end #do block end
           else
            xml.pdc_applicant {
              xml.participant_id ""
                xml.concern_role_id ""
                    xml.applicant_name ""
                xml.consent_applicant ""
                xml.is_enrolled_for_es_coverage ""
                xml.is_without_assistance ""
                xml.years_to_renew_coverage ""
                xml.financial_assistance ""
                xml.ia_eligible ""
                xml.medicaid_chip_eligible ""
                xml.receiving_benefit ""
                xml.projected_amount ""
                xml.participant_projected_income ""
                xml.projected_income_start_date ""
                xml.projected_income_end_date ""
                xml.application_submission_date ""
            } #pdc_applicant
            end # pdc person end
          } #pdc_applicants
          xml.pdc_status_code ""
          xml.pdc_registration_date ""
          xml.created_at ""
          xml.modified_at ""
        } #product_delivery_case
           
     end # PDC each block end
      
    } #product_delivery_cases
          xml.created_at ""
        xml.modified_at ""
  }
    }
   
end #builder new end

builder.to_xml

end #method


end #module




