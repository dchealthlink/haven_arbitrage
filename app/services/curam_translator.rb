require "bunny"
require "nokogiri"
require "./config/secret.rb"
require "./app/validations/xml_validator.rb"
require "./app/notifications/slack_notifier.rb"
Dir["./app/helpers/*.rb"].each {|file| require file }



class Curam_Translator


  include Curam_ESB_Service
  include Publish
  include Store
  include EA_Response_builder


def create_channel(host, vhost, port, user, password)
      conn = Bunny.new(:hostname => host, :vhost => vhost, :port => port, :user => user, :password => password)
      conn.start
      ch = conn.create_channel
      #ch.prefetch(1)
      return ch
end


	def translate
	  ch = create_channel(HAVEN_RABBIT_AUTH[:host], HAVEN_RABBIT_AUTH[:vhost], HAVEN_RABBIT_AUTH[:port], HAVEN_RABBIT_AUTH[:user], HAVEN_RABBIT_AUTH[:password])
      q = ch.queue(RABBIT_QUEUES[:curam_ic], durable: true)
      $CURAM_LOG.info("[*] Waiting for messages. on Queue: #{RABBIT_QUEUES[:curam_ic]} To exit press CTRL+C")

		begin
		  q.subscribe(:manual_ack => true, :block => true) do |delivery_info, properties, body|
		  	$CURAM_LOG.info("Received: delivery_info:  #{delivery_info}\nproperties:  #{properties}\nbody:  #{body}\n")
		    parse_queue_message(body.to_s)
		    process
		    ch.ack(delivery_info.delivery_tag)
	  	    $CURAM_LOG.info("[x] Finshed with Curam XML translation")
		   end
		rescue Interrupt => _
		  conn.close
		end	
	end


   def process
   	curam_response = Curam_ESB_Service.call(@ic_hash[:ic])
	validator = Validate_XML.new(curam_response)
	    if validator.check_syntax_error.any?
	   		error_message = validator.get_syntax_error_message
	   		#todo where to notify if invalid xml recieved
	   		Slack_it.new.notify("Curam payload recieved with IC: #{@ic_hash[:ic]} and xml for this IC is invalid with following errors.\nSyntax errors found: #{error_message}")
	   	else
	   		Slack_it.new.notify("Curam payload recieved with IC: #{@ic_hash[:ic]} and xml for this IC is valid")
	    complete = store_to_haven_db(curam_response)
	    consistent = curam_inconsistent_app_check
	    if ( complete && consistent )
	    	Slack_it.new.notify("\nIt is a complete and consistent application\n****************************\n")
	    	puts "***********************Hurray validations success******************************"
	    EA_Response_builder.call_haven(curam_response)
	    else
	    	Slack_it.new.notify("\nbut it is an incomplete or inconsistent application\n****************************\n")
	    end
	    end
   end


	def parse_queue_message(body)
		xml = Nokogiri::XML(body)
		@ic_hash = {}
		@ic_hash[:ic] = xml.search("IntegratedCase_ID").text
		@req_type = xml.search("req_type").text 
		req_type(@req_type)
		#message_hash[:some_value] = xml.search("some_value").text  Soon an additional field will add to IC payload structure
		@ic_hash
	end

end


 # 1.times do |i|
	#   fork do	
	  Curam_Translator.new.translate
	  # end
	  # end
	  # Process.waitall

