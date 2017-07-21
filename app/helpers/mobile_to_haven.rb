require 'json'
require 'rest-client'
$LOG = Logger.new('./log/log_file.log', 'monthly')


# This class translates a payload from Mobile's JSON format to HAVEN's pipedelimited input format
# and uploads it to an ingestor, like so:
# 
# 
#                                              +---------+
#                                              |pipe     |
#                                              |delimited|
#    +--------+          +------------------+  |payload  |    +---------------------+
#    | CV XML +--------> | haven_arbitrage  |  +---+-----+    |                     |
#    +--------+          |                  |      |          | file_input_wrapper  |
#                        |   translator     +------+--------->+                     |
#  +-------------+       |                  |                 | DB row ingesting    |
#  |mobile JSON  +-----> |  (you are here)  |                 |                     |
#  +-------------+       +------------------+                 +--------+------------+
#                                                                      |
#                                                                      |
#                                                               +------v------+
#                                        +----------+         ++               ++
#                                        |          |         | +-------------+ |
#                                        | internal |         |                 |
#                                        |  HAVEN   |  <------+  HAVEN input    |
#                                        |  JSON    |         |    database     |
#                                        |          |         +                 |
#                                        +----------+          ++             +-+
#                                                               +------------+

IngestorURL = 'newsafehaven.dcmic.org/file_input_wrapper.php'
SystemWrapperURL = 'newsafehaven.dcmic.org/finapp_system_wrapper.php'


class MobileTranslator

  def log_info(msg)
    $LOG.info("***********************\n\n#{msg}\n**********************\n\n")
  end

  def post_payload_to_ingestor(payload, faa_id)
    
    begin
      is_error_response = ->(response){ response.body.include? ("Error description:") }
    end

    file_input_wrapper_response = RestClient.post(IngestorURL, payload)
    log_info(file_input_wrapper_response)
    puts "file_input_wrapper_response: #{file_input_wrapper_response}"

    unless is_error_response(file_input_wrapper_response)
      payload = JSON.unparse({finAppId: faa_id})
      puts "file_input_wrapper_response payload: #{payload}"
      finapp_system_wrapper_response = RestClient.post(SystemWrapperURL, payload)
      log_info(finapp_system_wrapper_response.body)
    end 
  end # ea_payload_post method end


  def to_haven(rabbitmq_message)
    (finapp_id, payload) = MobileJSONToPipeDelimited.transform_payload(rabbitmq_message)
    post_payload_to_ingestor(payload, finapp_id)
  end

end