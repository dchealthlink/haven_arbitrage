require 'savon'
require 'nokogiri'
require 'logger'
require 'rest-client'
require './config/secret.rb'
$LOG = Logger.new('./log/curam.log', 'monthly')

class Ancillary_ESB_Calls

def initialize  
 savon_config = {
   :wsdl => CURAM_ESB_SOAP[:wsdl_ancillary_pull],
   :ssl_verify_mode => :none,
   :ssl_version => :TLSv1,
   :open_timeout => 100,
   :read_timeout => 100,
   :log => true,
  #:log_level => :debug,
   :logger => $LOG
}
@client = Savon.client(savon_config)
#@client.operations => [:curam_user_look_up, :five_year_bar, :income_pull, :deductions, :tax_dependents, :filer_consent]
end



def incomes(concern_role_id)

payload = %Q{<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:inc="http://xmlns.oracle.com/pcbpel/adapter/db/sp/IncomeReqService">
   <soapenv:Header/>
   <soapenv:Body>
      <inc:IncomeInputParameters>
         <!--Optional:-->
         <inc:I_CONCERNROLEID>#{concern_role_id}</inc:I_CONCERNROLEID>
      </inc:IncomeInputParameters>
   </soapenv:Body>
</soapenv:Envelope>}

response = @client.call(:income_pull, xml: payload)
income_block = Nokogiri::XML(response.xml).remove_namespaces!.search("income")
haven_ext_log("concern_role_id", concern_role_id, "Income", response)
$LOG.info(income_block.to_xml)
income_block
end


def five_year_bar(concern_role_id)
#1176119585045217280
payload = %Q{<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:fiv="http://xmlns.oracle.com/pcbpel/adapter/db/sp/FiveYearBarService">
   <soapenv:Header/>
   <soapenv:Body>
      <fiv:InputParameters>
         <!--Optional:-->
         <fiv:I_CONCERNROLEID>#{concern_role_id}</fiv:I_CONCERNROLEID>
      </fiv:InputParameters>
   </soapenv:Body>
</soapenv:Envelope>}

response = @client.call(:five_year_bar, xml: payload)
fyb_block = Nokogiri::XML(response.xml).remove_namespaces!
haven_ext_log("concern_role_id", concern_role_id, "Five Year Bar", response)
$LOG.info(fyb_block.to_xml)
fyb_block.xpath("//five_year_bar").children.to_s
end


def deductions(concern_role_id)
   #-4291220057293324288
   payload = %Q{<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ded="http://xmlns.oracle.com/pcbpel/adapter/db/sp/DeductionsService">
   <soapenv:Header/>
   <soapenv:Body>
      <ded:DeductionsInput>
         <!--Optional:-->
         <ded:I_CONCERNROLEID>#{concern_role_id}</ded:I_CONCERNROLEID>
      </ded:DeductionsInput>
   </soapenv:Body>
</soapenv:Envelope>}

response = @client.call(:deductions, xml: payload)
deduction_block = Nokogiri::XML(response.xml).remove_namespaces!.search("deduction")
haven_ext_log("concern_role_id", concern_role_id, "Deduction", response)
$LOG.info(deduction_block.to_xml)
deduction_block
end

def tax_dependents(concern_role_id)
   #6194000082497437696 Venu testcase filer 2 dependents
   payload = %Q{<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tax="http://xmlns.haven.dc.govcom/haven/taxdepdetailsin">
   <soapenv:Header/>
   <soapenv:Body>
      <tax:TaxDep_InputParameters>
         <!--Optional:-->
         <tax:I_CONCERNROLEID>#{concern_role_id}</tax:I_CONCERNROLEID>
      </tax:TaxDep_InputParameters>
   </soapenv:Body>
</soapenv:Envelope>}

response = @client.call(:tax_dependents, xml: payload)
tax_dependent_block = Nokogiri::XML(response.xml).remove_namespaces!.search("tax_dependents")
haven_ext_log("concern_role_id", concern_role_id, "Tax Dependent", response)
$LOG.info(tax_dependent_block.to_xml)
tax_dependent_block
end


def filer_consent(ic)
   #ic : 4150378
   puts "IC: #{@ic}"
   payload = %Q{<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:fil="http://xmlns.haven.dc.govcom/haven/FilerConsentIn">
   <soapenv:Header/>
   <soapenv:Body>
      <fil:TaxDep_InputParameters>
         <fil:IC_Input_List>#{ic}</fil:IC_Input_List>
      </fil:TaxDep_InputParameters>
   </soapenv:Body>
</soapenv:Envelope>}

response = @client.call(:filer_consent, xml: payload)
filer_consent_block = Nokogiri::XML(response.xml).remove_namespaces!
haven_ext_log("integrated_case_reference", ic, "Filer Consent", response)
$LOG.info(filer_consent_block.to_xml)
filer_consent_block.xpath("//filer_consent").children.to_s
end   


def haven_ext_log(keyindex, keyvalue, keytype, payload)
payload = {

"action" => "INSERT", 
"Location" => "external_log", 
"xaid" => "value", 
"keyindex" => "#{keyindex}", #integrated_case_reference or concern_role_id
"keyvalue" => "#{keyvalue}", #actual value of integrated_case_reference or concern_role_id
"keytype" => "#{keytype}",
"keyresultid" => "",#$icid != nil ? $icid : "",
"status" => "Success",
"keytimestamp" => Time.now.to_s,
"queuename" => "Ancillary Pull",
"apprefnum" => "",
"requesttype" => "Sent",
"xmlpayload" => "#{payload}"

}

$LOG.info("Log Curam Ancillary Intake: #{payload.to_s.gsub("=>", ":")}\n\n")
application_in_res = RestClient.post('newsafehaven.dcmic.org/external_log_test.php', payload.to_s.gsub("=>", ":"), {content_type: :"application/json", accept: :"application/json"})
$LOG.info("Log curam Ancillary response body: #{application_in_res.body}")
application_in_res.body
end


end #class end


#puts "value:#{Ancillary_ESB_Calls.new.five_year_bar(1176119585045217280)}"
#puts "value:#{Ancillary_ESB_Calls.new.filer_consent(2099584)}"
#puts "value:#{Ancillary_ESB_Calls.new.incomes(6507753396294909952)}"

# @ancillary_esb_calls = Ancillary_ESB_Calls.new(3741790085394202624)
# @tax_dependents = @ancillary_esb_calls.tax_dependents
# puts "Value : #{@tax_dependents}"
# @tax_dependents.each do |tax_dependents|
# if tax_dependents.search("*").text != ""
#   tax_dependents.search("tax_dependent").each do |dependent|
#    puts "dependent inspect: #{dependent}"
# end
# end
# end
  



