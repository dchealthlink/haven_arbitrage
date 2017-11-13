require 'savon'
require 'nokogiri'
require 'logger'
require 'rest-client'
require './config/secret.rb'
$LOG = Logger.new('./log/curam.log', 'monthly')

class Ancillary_ESB_Calls

def initialize(*arg)  
 savon_config = {
   :wsdl => CURAM_ESB_SOAP[:wsdl_ancillary_pull],
   :ssl_verify_mode => :none,
   :ssl_version => :TLSv1,
   :open_timeout => 100,
   :read_timeout => 100,
   :log => true,
  #:log_level => :debug,
   :logger => $LOG,
   :wsse_auth => CURAM_ESB_SOAP[:usercredentials]
}
@client = Savon.client(savon_config)
@ic = arg[0]
#@client.operations => [:curam_user_look_up, :five_year_bar, :income_pull, :deductions, :tax_dependents, :filer_consent]
@payload_header = %Q{<soapenv:Header>
      <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd" xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
         <wsse:UsernameToken wsu:Id="UsernameToken-E7F1EEEE943B258D3215089397579941">
            <wsse:Username>#{CURAM_ESB_SOAP[:usercredentials][0]}</wsse:Username>
            <wsse:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText">#{CURAM_ESB_SOAP[:usercredentials][1]}</wsse:Password>
            <wsse:Nonce EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary">yh3AxA8d/3vl40Fsqb3oUg==</wsse:Nonce>
            <wsu:Created>#{Time.now}</wsu:Created>
         </wsse:UsernameToken>
      </wsse:Security>
   </soapenv:Header>}
end


def incomes(concern_role_id)
payload = %Q{<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:inc="http://xmlns.oracle.com/pcbpel/adapter/db/sp/IncomeReqService">
   #{@payload_header}
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


def five_year_bar(concern_role_id) #payload have 2 arguements IC and Concern role ID
#1176119585045217280
payload = %Q{<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:fiv="http://xmlns.oracle.com/pcbpel/adapter/db/sp/FiveYearBarService">
   #{@payload_header}
   <soapenv:Body>
      <fiv:InputParameters>
         <!--Optional:-->
         <fiv:i_IC>#{@ic}</fiv:i_IC>
         <!--Optional:-->
         <fiv:i_concernroleid>#{concern_role_id}</fiv:i_concernroleid>
      </fiv:InputParameters>
   </soapenv:Body>
</soapenv:Envelope>
 }

response = @client.call(:five_year_bar, xml: payload)
fyb_block = Nokogiri::XML(response.xml).remove_namespaces!
haven_ext_log("concern_role_id", concern_role_id, "Five Year Bar", response)
$LOG.info(fyb_block.to_xml)
fyb_block.xpath("//five_year_bar").children.to_s
end


def deductions(concern_role_id)
   #-4291220057293324288
   payload = %Q{<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ded="http://xmlns.oracle.com/pcbpel/adapter/db/sp/DeductionsService">
   #{@payload_header}
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
   #{@payload_header}
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
   payload = %Q{<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:fil="http://xmlns.haven.dc.govcom/haven/FilerConsentIn">
   #{@payload_header}
   <soapenv:Body>
      <fil:Filer_InputParameters>
         <fil:IC_Input_List>#{ic}</fil:IC_Input_List>
      </fil:Filer_InputParameters>
   </soapenv:Body>
</soapenv:Envelope>
 }

response = @client.call(:filer_consent, xml: payload)
filer_consent_block = Nokogiri::XML(response.xml).remove_namespaces!
haven_ext_log("integrated_case_reference", ic, "Filer Consent", response)
$LOG.info(filer_consent_block.to_xml)
filer_consent_block.xpath("//filer_consent").children.to_s
end   

def is_resident(concern_role_id)
   payload = %Q{<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:isr="http://xmlns.oracle.com/pcbpel/adapter/db/sp/IsResidentReqService">
   #{@payload_header}
   <soapenv:Body>
      <isr:IsResidentInputParameters>
         <!--Optional:-->
         <isr:i_IC>#{@ic}</isr:i_IC>
         <!--Optional:-->
         <isr:i_CRID>#{concern_role_id}</isr:i_CRID>
      </isr:IsResidentInputParameters>
   </soapenv:Body>
</soapenv:Envelope>}

response = @client.call(:is_resident, xml: payload)
is_resident_block = Nokogiri::XML(response.xml).remove_namespaces!
haven_ext_log("concern_role_id", concern_role_id, "Is Resident", response)
$LOG.info(is_resident_block.to_xml)
is_resident_block.at_xpath("//is_resident").text.to_s
end

def insurance(concern_role_id)
   payload = %Q{<soapenv:Envelope xmlns:req="https://openhbx.gov/haven/insurancedetails/request" xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
   #{@payload_header}
   <soapenv:Body>
      <req:InsurnaceInput>
         <req:I_CONCERNROLEID>#{concern_role_id}</req:I_CONCERNROLEID>
      </req:InsurnaceInput>
   </soapenv:Body>
</soapenv:Envelope>}

response = @client.call(:insurance, xml: payload)
insurance_block = Nokogiri::XML(response.xml).remove_namespaces!.search("benefit")
haven_ext_log("concern_role_id", concern_role_id, "Insurance", response)
$LOG.info(insurance_block.to_xml)
insurance_block
end


def haven_ext_log(keyindex, keyvalue, keytype, payload)
payload = {

"action" => "INSERT", 
"Location" => "external_log", 
"xaid" => "value", 
"keyindex" => "#{keyindex}", #integrated_case_reference or concern_role_id
"keyvalue" => "#{keyvalue}", #actual value of integrated_case_reference or concern_role_id
"keytype" => "#{keytype}",
"altid" => "#{@ic}",
"keyresultid" => "",#$icid != nil ? $icid : "",
"status" => "Success",
"keytimestamp" => Time.now.to_s,
"queuename" => "Ancillary Pull",
"apprefnum" => "",
"requesttype" => "Sent",
"xmlpayload" => "#{payload}"

}

$LOG.info("Log Curam Ancillary Intake: #{payload.to_s.gsub("=>", ":")}\n\n")
application_in_res = RestClient.post(HAVEN_WEB_SERVICES[:c2h_external_log_test], payload.to_s.gsub("=>", ":"), {content_type: :"application/json", accept: :"application/json"})
$LOG.info("Log curam Ancillary response body: #{application_in_res.body}")
application_in_res.body
end


end #class end

# puts "value:#{Ancillary_ESB_Calls.new(2217363).five_year_bar(2929548264334163968)}"
# puts "value:#{Ancillary_ESB_Calls.new(2217363).tax_dependents(2929548264334163968)}"
# puts "value:#{Ancillary_ESB_Calls.new(2217363).incomes(2929548264334163968)}"
# puts "value:#{Ancillary_ESB_Calls.new(2217363).deductions(2929548264334163968)}"
# puts "value:#{Ancillary_ESB_Calls.new(2217363).filer_consent(2217363)}"
#puts "value:#{Ancillary_ESB_Calls.new(3570910).is_resident(-8102400690883657728)}"



