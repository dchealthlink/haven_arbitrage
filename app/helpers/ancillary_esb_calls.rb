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
#[:curam_user_look_up, :five_year_bar, :income_pull, :deductions]
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
Nokogiri::XML(response.xml).remove_namespaces!.xpath("//five_year_bar").children.to_s
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
Nokogiri::XML(response.xml).remove_namespaces!.search("deduction")
end

end
# #for Tom
# def test
# arr = [1035269362388303872, 7808683201953529856, -583477698072936448, -7629987411111444480, 91497526552690688, -8333695211033067520,
# -2879832179636961280, -7484332760727814144, -7885153127563788288, -7977554435494641664, 5762160568496553984, 3494811461371297792,
#  2253966409937715200, 3955722724235542528, -7109430880845692928, 5518822152595308544, 3863454165153873920, -8167321217506738176,
#  4262406393014779904, -1002094210360279040]
# arr.each do |cid|

# @doc = Nokogiri::XML(Ancillary_ESB_Calls.new.five_year_bar(cid))
# File.open('five_year_bar.text', 'a') { |f|
#   f.write "concern_role_id: #{cid}\n\n#{@doc.to_xml}\n\n\n"
# }
# #puts @doc.to_xml
# end
# end

# test

puts "value:#{Ancillary_ESB_Calls.new.deductions(-2223093480639430656)}"


