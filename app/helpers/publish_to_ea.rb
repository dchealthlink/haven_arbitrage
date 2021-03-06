require "bunny"
require "json"
require "./config/secret.rb"
$EA_LOG = Logger.new('./log/ea.log', 'monthly')


class Publish_EA

	def initialize(properties)
	   @conn = Bunny.new(:hostname => EA_RABBIT_AUTH[:host], :vhost => EA_RABBIT_AUTH[:vhost] , :port => EA_RABBIT_AUTH[:port], :user => EA_RABBIT_AUTH[:user], :password => EA_RABBIT_AUTH[:password])
      @conn.start
      @channel = @conn.create_channel
      @properties = properties
      @headers = @properties[:headers]
      #@queue = @channel.queue(RABBIT_QUEUES[:ea_intake_error], durable: true)
      @exchange = @channel.fanout( EA_RABBIT_AUTH[:exchange], :durable => true)
   end


   def error_intake_status(error_message, return_status)
      @headers.merge!(return_status: "#{return_status}")
      @headers["submitted_timestamp"] = @headers["submitted_timestamp"].to_s  #RabbitMQ conplaints on non string time stamp
      message = { error_message: error_message.to_s }.to_json
      @exchange.publish(message, :routing_key => EA_RABBIT_AUTH[:routing_key], :persistant => true, :content_type=>"application/octet-stream", :headers => @headers, :correlation_id => @properties[:correlation_id], :timestamp => Time.now.to_i, :app_id => @properties[:app_id])
   	@conn.close
      $EA_LOG.debug("Invalid/Inconsistent XML payload with Error messages: #{error_message} \nand published message back to EA with headers:#{@headers}")
   end



end


# properties = {:content_type=>"application/octet-stream", :headers=>{"submitted_timestamp" => 2017-07-12 21:20:43, "correlation_id"=>"95ac2247f1254e629178b201a71b59da", "family_id"=>"5953cc18d7c2dc0b1b00000a", "application_id"=>"5953cc4ad7c2dc0b51000001"}, :delivery_mode=>2, :priority=>0, :correlation_id=>"95ac2247f1254e629178b201a71b59da", :timestamp=>Time.now, :app_id=>"enroll"}

# message = %Q{Opening and ending tag mismatch: i_dental_only line 21 and is_dental_only
# Opening and ending tag mismatch: active_year line 20 and benchmark_plan
# Opening and ending tag mismatch: active_year line 20 and financial_assistance_application
# Premature end of data in tag benchmark_plan line 15
# Premature end of data in tag financial_assistance_application line 2}
# Publish_EA.new(properties).error_intake_status(message)


#EA RabbitMQ properties and headers structure
#properties:  {:content_type=>"application/octet-stream", :headers=>{"submitted_timestamp"=>2017-07-12 21:20:43 -0400, "correlation_id"=>"95ac2247f1254e629178b201a71b59da", "family_id"=>"5953cc18d7c2dc0b1b00000a", "application_id"=>"5953cc4ad7c2dc0b51000001"}, :delivery_mode=>2, :priority=>0, :correlation_id=>"95ac2247f1254e629178b201a71b59da", :timestamp=>2017-07-12 21:20:43 -0400, :app_id=>"enroll"}

