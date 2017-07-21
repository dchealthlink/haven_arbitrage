require 'json'
require 'yaml'

require_relative '../lib/mobile/mobile_json_to_pipe_delimited'

id, payload = MobileJSONToPipeDelimited.new.transform_payload(ARGF.read)

puts payload
