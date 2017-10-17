require 'rest-client'
require 'nokogiri'
require "securerandom"
require "json"
require 'logger'
require './app/models/application_xlate.rb'
require './app/helpers/publish.rb'
require "./app/notifications/slack_notifier.rb"
require "./app/helpers/ancillary_esb_calls.rb"
$CURAM_LOG = Logger.new('./log/curam.log', 'monthly')



module Store

  extend Publish

#adding req_type from IC payload structure to finapp_in table for projected eligibility
def req_type(req_type)
@req_type = req_type
end

def payload_post(payload)
  @payload = payload
   post_payload = @payload.to_s.gsub("=>", ":")
   $CURAM_LOG.info("#{"*"*100}\n#{@payload}\n\n")
   application_in_res = RestClient.post('newsafehaven.dcmic.org/arb_input_wrapper.php', post_payload, {content_type: :"application/xml", accept: :"application/json"})
    
   if @payload["Location"] == "application_in" 
      #fix this
      $icid =  JSON.parse(application_in_res.body)["Return"].first["icid"]
   end

   $CURAM_LOG.info("#{application_in_res}\n\n")

   curam_incomplete_app_check
end

#Posting email notices to application_in_status table 
def application_in_status(statustype)
 notice_payload = {"Action"=>"INSERT", "Location"=>"application_in_status", "xaid"=>"#{SecureRandom.uuid}", "Data"=>[{"keyfld"=>"#{@integrated_case_reference}", "keyid"=>"#{$icid}", "icnumber"=>"#{@integrated_case_reference}", "icid"=>"#{$icid}",
                   "statustype"=>"#{statustype}", "statustimestamp"=>"#{Time.now}", "applicationsource"=>"curam"}]}
 application_in_status = RestClient.post('newsafehaven.dcmic.org/arb_input_wrapper.php', notice_payload.to_s.gsub("=>", ":"), {content_type: :"application/xml", accept: :"application/json"})
 puts "Notice Payload: #{notice_payload}\n\n Application in status: #{application_in_status}"
end  

#*****************************Validations Incomplete/Inconsistant ***************************#
def curam_incomplete_app_check

if !@notice.empty? && (@payload["Location"] == "application_pdc_person_in")
 message = "IC: #{@integrated_case_reference}\n\nInfo: \n#{@notice.join(" \n")} \n"
 email_notice(message)
 Slack_it.new.notify(message)  #slack notification
 application_in_status("incomplete")
 @notice.clear
end

mandatory_fields = @application_xlate.select {|value| value[:mandatory] == "Y" && value[:targettype] == @payload["Location"]}
#puts "Mandatory field list: **** #{mandatory_fields.inspect}"

payload_fields = @payload["Data"].first.keys

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
    
    puts "send notifications: #{value.sourcefield} missing in curam xml in payload: #{@payload["Location"]}"
    #puts "payload keys: #{payload_fields}"
    tf << false
  end

end
  unless @missing_fields.empty?
    message = "IC: #{@payload["Data"].first["icnumber"]}\n\nError: <#{@missing_fields.join(", ")}> value missing in curam data
                \n"
    email_notice(message)
    Slack_it.new.notify(message)
  end
#puts "tf: #{tf}"
return tf.all? {|value| value == true} ? true : false
end #unless condition
end #method


def curam_inconsistent_app_check
 
  if @curam_xml.xpath("//curam_applicant").count >= 2 && @curam_xml.xpath("//relationship").text.strip.empty?
    message = "Hello\n\n IC: #{@integrated_case_reference}\n\nError: No relationship data found in curam xml
                \n"
    email_notice(message)
    Slack_it.new.notify(message)
    application_in_status("inconsistent")
    return false
  # elsif curam_response.xpath("//relationship").text.include?("Is Unrelated to")
  #    message = "Hello\n\n IC: #{ic}\n\nError: There is an unrelated applicant in this application and we don't like that.
  #               \n\n\n\n\n Thanks,\n -Arbitrage"
  #   email_notice(message)
  #   return false
  else
    return true
  end
end
  


def log_curam_intake

payload = {

"action" => "INSERT", 
"Location" => "external_log", 
"xaid" => "value", 
"keyindex" => "integrated_case_reference",
"keyvalue" => @curam_xml.xpath("//integrated_case_reference").text,
"keytype" => "Curam",
"keyresultid" => $icid != nil ? $icid : "",
"status" => "Success",
"keytimestamp" => Time.now.to_s,
"queuename" => "Haven_ICID_RMQ",
"apprefnum" => @curam_xml.xpath("//AppCaseRef").text.to_s,
"requesttype" => "Sent",
"xmlpayload" => "#{@curam_raw_xml}"

}

puts "Log Curam Intake: #{payload.to_s.gsub("=>", ":")}\n\n"
application_in_res = RestClient.post('newsafehaven.dcmic.org/external_log_test.php', payload.to_s.gsub("=>", ":"), {content_type: :"application/json", accept: :"application/json"})
puts "Log curam response body: #{application_in_res.body}"
application_in_res.body
end



#***************************************************************************************#




def curam_xlate(st, tt, sf, tf, sv)
  
  check_flag =  @application_xlate.select do |value|
     value[:targettype] == "#{tt}" && value[:sourcefield].downcase == "#{sf}".downcase && value[:targetfield] == "#{tf}"
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
    xlate =  check_flag.select { |value| value[:targettype] == "#{tt}" && value[:sourcefield].downcase == "#{sf}".downcase && value[:sourcevalue].downcase == "#{sv}".downcase }
      #value[:sourcein] == "curam" && value[:targetout] == "haven" && value[:targettype] == "application_person_income_in" && value[:sourcefield] == "end_date" && value[:sourcevalue] == "2017-12-01"
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
    sv = customize_default_value(default_field.first.defaultvalue)
    @notice << "source value missing for <#{sf}> so assuming the value : <#{sv}>"
    puts "source value missing for <#{sf}> so assuming the value : <#{sv}>"
  end
  end
    
  return sv

else
  payload = "Error: Record not Fount on app xlate table with values --> SI:curam, TO:haven, ST:#{st}, TT:#{tt}, SF:#{sf}, SV:#{sv}"
  return ""
  end

end

def customize_default_value(value) 
default_value = value
default_value = ("9" + 8.times.map{rand(10)}.join) if value == "10 digit random acrn"

default_value
end

def data_block(st, tt, records)
arr = @application_xlate.select { |value| value[:targettype] == tt }
hs = {}
#puts "In fields:  #{arr}" 
arr.uniq { |value| (value.targetfield) }.each do |val|
  #arr.uniq { |value| (value.targetfield && value.sourcefield) }.each do |val|
  
    
  source_value = curam_xlate(st, tt, val.sourcefield, val.targetfield, xml_search(records, val.sourcefield))
  hs[val.targetfield.to_s] = source_value if (source_value != "" && source_value.class.to_s != "Array")

# Dirty patch for deductions type field
  # if val.targetfield == "incometype"
  #   source_value = curam_xlate(st, tt, "type", val.targetfield, xml_search(records, "type"))
  #   hs[val.targetfield.to_s] = source_value if (source_value != "" && source_value.class.to_s != "Array")
  # end
  
end
hs.merge!("icnumber" => @integrated_case_reference)
#puts "Insert record: #{hs.inspect}"
return hs
end


def xml_search(records, field)
begin
records.search(field).children.first.text.to_s 
#puts "XML search for #{field}: #{records.search(field).text}"
#records.search(field).text.to_s 
rescue
  $CURAM_LOG.info("%%%%%%%%%% Unable to find the value for #{field} in curam xml%%%%%%%%%%%")
  return ""
end
end


def store_to_haven_db(curam_xml)

curam_response = Nokogiri::XML(curam_xml)
@curam_xml = Nokogiri::XML(curam_xml)
@curam_raw_xml = curam_xml
@notice = []
@tax_no = 1
@application_xlate = Application_xlate.where(["sourcein=? and targetout=? and status=?", "curam", "haven", "A"]).to_a

@integrated_case_reference = @curam_xml.xpath("//integrated_case_reference").text.to_s
 
log_curam_intake


#**************************************************************#
application_in_payload = {

 "Action" => "INSERT",
 "Location" => "application_in",
 "xaid" => "#{SecureRandom.uuid}",
 "Data" => [((@req_type != nil && @req_type != "") ? data_block("application", "application_in", @curam_xml).merge!("reqtype" => @req_type) : data_block("application", "application_in", @curam_xml))]

}


@application_in = payload_post(application_in_payload)

#**************************************************************#



#****************************Person In payload****************************************#
@curam_xml.xpath("//curam_applicant").each_with_index do |applicant, applicant_num|

  @concern_role_id = applicant.search("concern_role_id").text.to_s 
#Add five year bar to person level
@ancillary_esb_calls = Ancillary_ESB_Calls.new
@five_year_bar = @ancillary_esb_calls.five_year_bar(@concern_role_id)
@filer_consent = @ancillary_esb_calls.filer_consent(@integrated_case_reference)
  
applicant.add_child(@five_year_bar)
applicant.add_child(@filer_consent)
  puts "applicant is : #{applicant}"

   


@curam_xml.search("pdc_applicant").each do |pdc_person|
  
  if @concern_role_id == pdc_person.search("concern_role_id").text.to_s 
    ic_and_pdc_person = "<curam_applicant>"+ applicant.children.to_s + pdc_person.children.to_s + "</curam_applicant>"
    applicant = Nokogiri::XML(ic_and_pdc_person) 
  end

end




application_person_in_payload = {

 "Action" => "INSERT",
 "Location" => "application_person_in",
 "xaid" => "#{SecureRandom.uuid}",
 "Data" => [data_block("curam_applicant", "application_person_in", applicant).merge!("icid" => $icid)]
  
  }

@application_person_in = payload_post(application_person_in_payload)


#*********************Address*************************************************************************#
applicant.search("address").each do |address|

if address.search("*").text != ""  
  application_person_address_in_payload = {

 "Action" => "INSERT",
 "Location" => "application_person_address_in",
 "xaid" => "#{SecureRandom.uuid}",
 "Data" => [data_block("curam_applicant", "application_person_address_in", address).merge!("personid" => @concern_role_id.to_s, "icid" => $icid)]
  
  }

@application_person_address_in = payload_post(application_person_address_in_payload)
end
end
#*****************************************************************************************************#



#**********************************Income*********************************************#
@incomeid = 1
@incomes = @ancillary_esb_calls.incomes(@concern_role_id)

#applicant.search("income").each do |income|

@incomes.each do |income|
if income.search("*").text != ""  

application_person_income_in_payload = { 

  "Action" => "INSERT",
  "Location" => "application_person_income_in",
  "xaid" => "#{SecureRandom.uuid}",
  "Data" => [data_block("income", "application_person_income_in", income).merge!("personid" => @concern_role_id.to_s, "icid" => $icid, "incomeid" => @incomeid)]
   
   }

@application_person_income_in = payload_post(application_person_income_in_payload)
@incomeid +=1
end
end
#**************************************************************************************#

#***********************************Benefits******************************************
applicant.search("benefit").each do |benefit|

if benefit.search("*").text != ""  
  application_person_benefit_in_payload = {

 "Action" => "INSERT",
 "Location" => "application_person_benefit_in",
 "xaid" => "#{SecureRandom.uuid}",
 "Data" => [data_block("benefit", "application_person_benefit_in", benefit).merge!("personid" => @concern_role_id.to_s, "icid" => $icid)]
  
  }

@application_person_benefit_in = payload_post(application_person_benefit_in_payload)
end
end


#*************************************************************************************



#***********************************Deductions****************************************
# #Note: Income and deductions store in same table --> "application_person_income_in"
@deductions = @ancillary_esb_calls.deductions(@concern_role_id)
#applicant.search("deduction").each do |deduction|
@deductions.each do |deduction| 

if deduction.search("*").text != ""  

application_person_deduction_in_payload = { 

  "Action" => "INSERT",
  "Location" => "application_person_income_in",
  "xaid" => "#{SecureRandom.uuid}",
  "Data" => [data_block("income", "application_person_income_in", deduction).merge!("personid" => @concern_role_id.to_s, "icid" => $icid, "incomeid" => @incomeid)]
   
   }

puts "Application deduction In: #{application_person_deduction_in_payload}"
@application_person_deduction_in = payload_post(application_person_deduction_in_payload)
@incomeid +=1
end
end
#************************************************************************************

#*********************************Relationships*****************************
applicant.search("relationship").each do |relationship|

if relationship.search("*").text != ""
  application_relationship_in_payload = {
  
  "Action" => "INSERT",
  "Location" => "application_relationship_in",
  "xaid" => "#{SecureRandom.uuid}",
  "Data" => [data_block("relationship", "application_relationship_in", relationship).merge!("personid" => @concern_role_id.to_s, "icid" => $icid)]
  
  }

@application_relationship_in = payload_post(application_relationship_in_payload)
end
end



case applicant.search("tax_filing_status").text 

  when "Tax Filer" 

    if applicant.search("tax_filing_together").text == "true"
    @tax_no = 1
    else
    @tax_no += 1
    end

# Filer post
  application_tax_in_payload = {
  "Action" => "INSERT",
  "Location" => "application_tax_in",
  "xaid" => "#{SecureRandom.uuid}",
  "Data" => [data_block("tax_relationship", "application_tax_in", applicant).merge!("icid" => $icid, "tax_no" => @tax_no)]
  }
  @application_tax_in = payload_post(application_tax_in_payload)
#Filer's dependents post

#applicant.search("tax_dependents").each do |tax_dependents|

@tax_dependents = @ancillary_esb_calls.tax_dependents(@concern_role_id)

@tax_dependents.each do |tax_dependents|
if tax_dependents.search("*").text != ""
  tax_dependents.search("tax_dependent").each do |dependent|
  
  application_tax_in_payload = {
  "Action" => "INSERT",
  "Location" => "application_tax_in",
  "xaid" => "#{SecureRandom.uuid}",
  "Data" => [data_block("tax_relationship", "application_tax_in", dependent).merge!("personid" => dependent.text.to_s, "filer_type" => "Dependents", "icid" => $icid, "tax_no" => @tax_no)]
  }
  @application_tax_in = payload_post(application_tax_in_payload)
end #do
end #do
end #if

  when "Non Filer"

# Non Filer post
  application_tax_in_payload = {
  "Action" => "INSERT",
  "Location" => "application_tax_in",
  "xaid" => "#{SecureRandom.uuid}",
  "Data" => [data_block("tax_relationship", "application_tax_in", applicant).merge!("icid" => $icid, "tax_no" => "99")]
  }
  @application_tax_in = payload_post(application_tax_in_payload)
end

end
#***********************************************************************#


  
# # #**************************************

@curam_xml.xpath("//product_delivery_case").each do |pdc|

@pdc_case_reference = pdc.search("pdc_case_reference").first.text.to_s

pdc_data = data_block("pdc", "application_pdc_in", pdc).merge!("icid" => $icid)

if pdc.search("pdc_product_type_description").children.text == "Insurance Assistance"
# APTC Extraction
          aptc = @curam_xml.search("aptc_amount")
          aptc_data = data_block("pdc", "application_pdc_in", aptc)
          pdc_data.merge!(aptc_data)
       

# CSR Extraction
          csr = @curam_xml.search("csr")
          csr_data = data_block("pdc", "application_pdc_in", csr)
          pdc_data.merge!(csr_data)
      
end


  application_pdc_in_payload = {

    "Action" => "INSERT",
    "Location" => "application_pdc_in",
      "xaid" => "#{SecureRandom.uuid}",
      "Data" => [pdc_data]
  
     }

@application_pdc_in = payload_post(application_pdc_in_payload)



pdc.search("pdc_applicant").each do |pdc_person|

application_pdc_person_in_payload = {
   
   "Action" => "INSERT",
   "Location" => "application_pdc_person_in",
     "xaid" => "#{SecureRandom.uuid}",  
     "Data" => [data_block("pdc", "application_pdc_person_in", pdc_person).merge!("pdcrefnum" => @pdc_case_reference, "icid" => $icid)]
 
   }


@application_pdc_person_in = payload_post(application_pdc_person_in_payload)




end
 end

arr = [@application_in, @application_person_in, @application_person_income_in, @application_person_address_in, 
                 @application_relationship_in, @application_pdc_in, @application_pdc_person_in]#.include?(false)

puts "arr: #{arr}"

arr.all? {|value| value == true || value == nil} ? true : false


end #method
end #module







