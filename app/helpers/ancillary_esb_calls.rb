require 'savon'
require 'nokogiri'
require 'logger'
$LOG = Logger.new('/Users/venumadhavdondapati/workspace/github_repos/haven_arbitrage/log/curam.log', 'monthly')

class Ancillary_ESB_Calls

def initialize
 savon_config = {
   :wsdl => "http://dhsdcasesbsoaappuat01.dhs.dc.gov:8011/HCLProxyService?wsdl",
   :ssl_verify_mode => :none,
   :ssl_version => :TLSv1,
   :open_timeout => 100,
   :read_timeout => 100,
   :log => true,
  #:log_level => :debug,
   :logger => $LOG
}
@client = Savon.client(savon_config)
end



def income(concern_role_id)

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
response.xml
end


def five_year_bar(concern_role_id)

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
response.xml
end


end



puts Nokogiri::XML(Ancillary_ESB_Calls.new.five_year_bar(1176119585045217280))




