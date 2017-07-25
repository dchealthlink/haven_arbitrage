require 'rest-client'
require 'nokogiri'
require "securerandom"
require "json"
require 'logger'
require './app/models/application_xlate.rb'
require './app/helpers/publish.rb'
$LOG = Logger.new('./log/curam.log', 'monthly')




module Store

  extend Publish

def payload_post(payload, xlate)
   post_payload = payload.to_s.gsub("=>", ":")
   $LOG.info("#{"*"*100}\n#{payload}\n\n")
   application_in_res = RestClient.post('newsafehaven.dcmic.org/arb_input_wrapper.php', post_payload, {content_type: :"application/xml", accept: :"application/json"})
    
   if payload["Location"] == "application_in" 
      #fix this
      $icid =  JSON.parse(application_in_res.body)["Return"].first["icid"]
   end

   RestClient.post('newsafehaven.dcmic.org/external_log.php', post_payload)
   $LOG.info("#{application_in_res}\n\n")

   curam_incomplete_app_check(payload, xlate)
end

#Posting email notices to application_in_status table 
def application_in_status(statustype)
 notice_payload = {"Action"=>"INSERT", "Location"=>"application_in_status", "xaid"=>"#{SecureRandom.uuid}", "Data"=>[{"keyfld"=>"#{$integrated_case_reference}", "keyid"=>"#{$icid}", "icnumber"=>"#{$integrated_case_reference}", "icid"=>"#{$icid}",
                   "statustype"=>"#{statustype}", "statustimestamp"=>"#{Time.now}", "applicationsource"=>"curam"}]}
 application_in_status = RestClient.post('newsafehaven.dcmic.org/arb_input_wrapper.php', notice_payload.to_s.gsub("=>", ":"), {content_type: :"application/xml", accept: :"application/json"})
 puts "Notice Payload: #{notice_payload}\n\n Application in status: #{application_in_status}"
end  

#*****************************Validations Incomplete/Inconsistant ***************************#
def curam_incomplete_app_check(payload, xlate)

#puts xlate.count
#xlate = Application_xlate.all
#puts "$notice: #{$notice.inspect}"
#puts "payload location: #{payload["Location"]}"
if !$notice.empty? && (payload["Location"] == "application_pdc_person_in")
 message = "IC: #{$integrated_case_reference}\n\nInfo: \n#{$notice.join(" \n")} \n\n\n Thanks,\n -Arbitrage"
 email_notice(message)
 application_in_status("incomplete")
 $notice.clear
end

mandatory_fields = xlate.select {|value| value[:sourcein] == "curam" && value[:targetout] == "haven" && value[:mandatory] == "Y" && value[:targettype] == payload["Location"]}
#puts "Mandatory field list: **** #{mandatory_fields.inspect}"

payload_fields = payload["Data"].first.keys

#puts "payload keys: #{payload_fields}"
unless mandatory_fields.empty?
  @missing_fields = []
  tf = []
mandatory_fields.uniq { |value| value.targetfield }.each do |value|

#puts "target field from xlate: #{value.targetfield.to_sym}"
  if payload_fields.include?(value.targetfield)
    tf << true
  else
   @missing_fields << value.sourcefield
    
    puts "send notifications: #{value.sourcefield} missing in curam xml in payload: #{payload["Location"]}"
    #puts "payload keys: #{payload_fields}"
    tf << false
  end

end
  unless @missing_fields.empty?
    message = "IC: #{payload["Data"].first["icnumber"]}\n\nError: <#{@missing_fields.join(", ")}> value missing in curam data
                \n\n\n Thanks,\n -Arbitrage"
    email_notice(message)
    validation_log
  end
#puts "tf: #{tf}"
return tf.all? {|value| value == true} ? true : false
end #unless condition
end #method


def curam_inconsistent_app_check(curam_xml)
  curam_response = Nokogiri::XML(curam_xml)
 ic =  curam_response.xpath("//integrated_case_reference").text.to_s
  
  if curam_response.xpath("//curam_applicant").count >= 2 && curam_response.xpath("//relationship").text.strip.empty?
    message = "Hello\n\n IC: #{ic}\n\nError: No relationship data found in curam xml
                \n\n\n\n\n Thanks,\n -Arbitrage"
    email_notice(message)
    validation_log
    application_in_status("inconsistent")
    return false
  # elsif curam_response.xpath("//relationship").text.include?("Is Unrelated to")
  #    message = "Hello\n\n IC: #{ic}\n\nError: There is an unrelated applicant in this application and we don't like that.
  #               \n\n\n\n\n Thanks,\n -Arbitrage & \n We love you Tom....!"
  #   email_notice(message)
  #   validation_log
  #   return false
  else
    return true
  end
end
  


def validation_log   

payload = {

"action" => "INSERT", 
"Location" => "external_log", 
"xaid" => "value", 
"keyindex" => "integrated_case_reference",
"keyvalue" => $curam_xml.xpath("//integrated_case_reference").text,
"keytype" => "Notification",
"keyresultid" => $icid,
"status" => "Success",
"keytimestamp" => Time.now,
"queuename" => "email-out",
"apprefnum" => $curam_xml.xpath("//AppCaseRef").text.to_s,
"requesttype" => "Sent",
"Data" => [ "payload" => $curam_raw_xml ]

}

puts "validation log: #{payload.to_s.gsub("=>", ":")}"
application_in_res = RestClient.post('newsafehaven.dcmic.org/arb_input_wrapper.php', payload.to_s.gsub("=>", ":"), {content_type: :"application/xml", accept: :"application/json"})
application_in_res.body
end


def log_curam_intake

payload = {

"action" => "INSERT", 
"Location" => "external_log", 
"xaid" => "value", 
"keyindex" => "integrated_case_reference",
"keyvalue" => $curam_xml.xpath("//integrated_case_reference").text,
"keytype" => "Curam",
"keyresultid" => $icid != nil ? $icid : "",
"status" => "Success",
"keytimestamp" => Time.now.to_s,
"queuename" => "Haven_ICID_RMQ",
"apprefnum" => $curam_xml.xpath("//AppCaseRef").text.to_s,
"requesttype" => "Sent",
"xmlpayload" => "#{$curam_raw_xml}"

}

puts "Log Curam Intake: #{payload.to_s.gsub("=>", ":")}\n\n"
application_in_res = RestClient.post('newsafehaven.dcmic.org/external_log_test.php', payload.to_s.gsub("=>", ":"), {content_type: :"application/json", accept: :"application/json"})
puts "Log curam response body: #{application_in_res.body}"
application_in_res.body
end



#***************************************************************************************#

def verify_date(date)
  if date == "0001-01-01"
  return "null"
  else
    date
  end
end



def curam_xlate(st, tt, sf, tf, sv, application_xlate)
  
  check_flag =  application_xlate.select do |value|
    value[:sourcein] == "curam" && value[:targetout] == "haven" && value[:targettype] == "#{tt}" && value[:sourcefield] == "#{sf}" && value[:targetfield] == "#{tf}"
  end

if check_flag.any? && sv != ""
  
   # case check_flag.first.siflag 
   #  when "N"
   #  xlate =  check_flag.select do |value|
   #    value[:sourcein] == "curam" && value[:targetout] == "haven" && value[:targettype] == "#{tt}" && value[:sourcefield] == "#{sf}" && value[:sourcevalue] == "#{sv}"  
   #    end
   #    puts xlate.inspect
   #  #puts "----------------#{sv}---------------------------"
   #  return xlate.any? ? xlate.first.targetvalue : ""#error_log("Error: #{xlate.inspect}")
   #  when "Y"
   #  return sv #== "0001-01-01" ? "" : sv
   # end

check_flag.each do |value|
   case value.siflag 
    when "N"
    xlate =  check_flag.select do |value|
      value[:sourcein] == "curam" && value[:targetout] == "haven" && value[:targettype] == "#{tt}" && value[:sourcefield] == "#{sf}" && value[:sourcevalue] == "#{sv}"  
      #value[:sourcein] == "curam" && value[:targetout] == "haven" && value[:targettype] == "application_person_income_in" && value[:sourcefield] == "end_date" && value[:sourcevalue] == "2017-12-01"
      end
    #   puts xlate.inspect
    # #puts "----------------#{sv}---------------------------"
    x = xlate.any? ? xlate.first.targetvalue : ""#error_log("Error: #{xlate.inspect}")
    if x == ""
      next
    else
      return x
    end
    when "Y"
    return sv #== "0001-01-01" ? "" : sv
   end
  end

elsif sv == "" #|| sv == "default" 
  #payload = "Error: No Source value from Curam for app xlate table with values --> curam, haven, st:#{st}, tt:#{tt}, sf:#{sf}, sv:#{sv}"
  #error_log(payload)
  if check_flag.any?
    default_field = check_flag.select { |value| value.siflag == "N" && value.sourcevalue == "default" }
    unless default_field.empty?
    sv = default_field.first.defaultvalue
    $notice << "source value missing for <#{sf}> so assuming the value : <#{sv}>"
    puts "source value missing for <#{sf}> so assuming the value : <#{sv}>"
  end
  end
    
  return sv

else
  payload = "Error: Record not Fount on app xlate table with values --> SI:curam, TO:haven, ST:#{st}, TT:#{tt}, SF:#{sf}, SV:#{sv}"
  error_log(payload)
  return ""
  end

end


def error_log(payload)
$LOG.info("Payload:*******#{payload}")
res = RestClient.post('newsafehaven.dcmic.org/external_log.php', payload)
end 


def data_block(application_xlate, st, tt, records, ic)
arr = application_xlate.select do |value|
  value[:sourcein] == "curam" && value[:targetout] == "haven" && value[:targettype] == tt
end
hs = {}
#puts "In fields:  #{arr}" 
arr.uniq { |value| value.targetfield }.each do |val|
  
  source_value = curam_xlate(st, tt, val.sourcefield, val.targetfield, xml_search(records, val.sourcefield), application_xlate)
  hs[val.targetfield.to_s] = source_value if (source_value != "" && source_value.class.to_s != "Array")
  
end
hs.merge!("icnumber" => ic)
#puts "Insert record: #{hs.inspect}"
return hs
end


def xml_search(records, field)
begin
records.search(field).children.first.text.to_s 
#puts "XML search for #{field}: #{records.search(field).text}"
#records.search(field).text.to_s 
rescue
  $LOG.info("%%%%%%%%%% Unable to find the value for #{field} in curam xml%%%%%%%%%%%")
  return ""
end
end


def store_to_haven_db(curam_xml)

curam_response = Nokogiri::XML(curam_xml)
$curam_xml = Nokogiri::XML(curam_xml)
$curam_raw_xml = curam_xml
$notice = []
$tax_no = 1
@application_xlate = Application_xlate.all

 @integrated_case_reference = curam_response.xpath("//integrated_case_reference").text.to_s
 $integrated_case_reference = curam_response.xpath("//integrated_case_reference").text.to_s

log_curam_intake
#**************************************************************#
application_in_payload = {

 "Action" => "INSERT",
 "Location" => "application_in",
 "xaid" => "#{SecureRandom.uuid}",
 "Data" => [data_block(@application_xlate, "application", "application_in", curam_response, @integrated_case_reference)]

}


@application_in = payload_post(application_in_payload, @application_xlate)

#**************************************************************#



#****************************Person In payload****************************************#
curam_response.xpath("//curam_applicant").each_with_index do |applicant, applicant_num|

   @concern_role_id = applicant.search("concern_role_id").text.to_s 
application_person_in_payload = {

 "Action" => "INSERT",
 "Location" => "application_person_in",
 "xaid" => "#{SecureRandom.uuid}",
 "Data" => [data_block(@application_xlate, "curam_applicant", "application_person_in", applicant, @integrated_case_reference).merge!("icid" => $icid)]
  
  }

@application_person_in = payload_post(application_person_in_payload, @application_xlate)


#*********************Address*************************************************************************#
applicant.search("address").each do |address|

if address.search("*").text != ""  
  application_person_address_in_payload = {

 "Action" => "INSERT",
 "Location" => "application_person_address_in",
 "xaid" => "#{SecureRandom.uuid}",
 "Data" => [data_block(@application_xlate, "curam_applicant", "application_person_address_in", address, @integrated_case_reference).merge!("personid" => @concern_role_id.to_s, "icid" => $icid)]
  
  }

@application_person_address_in = payload_post(application_person_address_in_payload, @application_xlate)
end
end
#*****************************************************************************************************#



#**********************************Income*********************************************#
applicant.search("income").each do |income|

if income.search("*").text != ""  

application_person_income_in_payload = { 

  "Action" => "INSERT",
  "Location" => "application_person_income_in",
  "xaid" => "#{SecureRandom.uuid}",
  "Data" => [data_block(@application_xlate, "income", "application_person_income_in", income, @integrated_case_reference).merge!("personid" => @concern_role_id.to_s, "icid" => $icid)]
   
   }

@application_person_income_in = payload_post(application_person_income_in_payload, @application_xlate)
end
end
#**************************************************************************************#




#*********************************Relationships*****************************
applicant.search("relationship").each do |relationship|

if relationship.search("*").text != ""
  application_relationship_in_payload = {
  
  "Action" => "INSERT",
  "Location" => "application_relationship_in",
  "xaid" => "#{SecureRandom.uuid}",
  "Data" => [data_block(@application_xlate, "relationship", "application_relationship_in", relationship, @integrated_case_reference).merge!("personid" => @concern_role_id.to_s, "icid" => $icid)]
  
  }

@application_relationship_in = payload_post(application_relationship_in_payload, @application_xlate)
end
end



case applicant.search("tax_filing_status").text 

  when "Tax Filer" 

    if applicant.search("tax_filing_together").text == "true"
    $tax_no = 1
    else
    $tax_no += 1
    end

# Filer post
  application_tax_in_payload = {
  "Action" => "INSERT",
  "Location" => "application_tax_in",
  "xaid" => "#{SecureRandom.uuid}",
  "Data" => [data_block(@application_xlate, "tax_relationship", "application_tax_in", applicant, @integrated_case_reference).merge!("icid" => $icid, "tax_no" => $tax_no)]
  }
  @application_tax_in = payload_post(application_tax_in_payload, @application_xlate)
#Filer's dependents post

applicant.search("tax_dependents").each do |tax_dependents|
if tax_dependents.search("*").text != ""
  tax_dependents.search("tax_dependent").each do |dependent|
  
  application_tax_in_payload = {
  "Action" => "INSERT",
  "Location" => "application_tax_in",
  "xaid" => "#{SecureRandom.uuid}",
  "Data" => [data_block(@application_xlate, "tax_relationship", "application_tax_in", dependent, @integrated_case_reference).merge!("personid" => dependent.text.to_s, "filer_type" => "Dependents", "icid" => $icid, "tax_no" => $tax_no)]
  }
  @application_tax_in = payload_post(application_tax_in_payload, @application_xlate)
end #do
end #do
end #if

  when "Non Filer"

# Non Filer post
  application_tax_in_payload = {
  "Action" => "INSERT",
  "Location" => "application_tax_in",
  "xaid" => "#{SecureRandom.uuid}",
  "Data" => [data_block(@application_xlate, "tax_relationship", "application_tax_in", applicant, @integrated_case_reference).merge!("icid" => $icid, "tax_no" => "99")]
  }
  @application_tax_in = payload_post(application_tax_in_payload, @application_xlate)
end

end
#***********************************************************************#


  
# # #**************************************

curam_response.xpath("//product_delivery_case").each do |pdc|

@pdc_case_reference = pdc.search("pdc_case_reference").first.text.to_s

pdc_data = data_block(@application_xlate, "pdc", "application_pdc_in", pdc, @integrated_case_reference).merge!("icid" => $icid)

if pdc.search("pdc_product_type_description").children.text == "Insurance Assistance"
# APTC Extraction
          aptc = curam_response.search("aptc_amount")
          aptc_data = data_block(@application_xlate, "pdc", "application_pdc_in", aptc, @integrated_case_reference)
          pdc_data.merge!(aptc_data)
       

# CSR Extraction
          csr = curam_response.search("csr")
          csr_data = data_block(@application_xlate, "pdc", "application_pdc_in", csr, @integrated_case_reference)
          pdc_data.merge!(csr_data)
      
end


  application_pdc_in_payload = {

    "Action" => "INSERT",
    "Location" => "application_pdc_in",
      "xaid" => "#{SecureRandom.uuid}",
      "Data" => [pdc_data]
  
     }

@application_pdc_in = payload_post(application_pdc_in_payload, @application_xlate)



pdc.search("pdc_applicant").each do |pdc_person|

application_pdc_person_in_payload = {
   
   "Action" => "INSERT",
   "Location" => "application_pdc_person_in",
     "xaid" => "#{SecureRandom.uuid}",  
     "Data" => [data_block(@application_xlate, "pdc", "application_pdc_person_in", pdc_person, @integrated_case_reference).merge!("pdcrefnum" => @pdc_case_reference, "icid" => $icid)]
 
   }


@application_pdc_person_in = payload_post(application_pdc_person_in_payload, @application_xlate)




end
 end

arr = [@application_in, @application_person_in, @application_person_income_in, @application_person_address_in, 
                 @application_relationship_in, @application_pdc_in, @application_pdc_person_in]#.include?(false)

puts "arr: #{arr}"

arr.all? {|value| value == true || value == nil} ? true : false


end #method
end #module







