require "bunny"
require './config/secret.rb'
require "./app/validations/xml_validator.rb"
require "./app/notifications/slack_notifier.rb"
Dir["./app/helpers/*.rb"].each {|file| require file }
# require "./app/helpers/publish_to_ea.rb"
# require "./app/helpers/ea_to_haven.rb"

class EA_Listener


def create_channel(host, vhost, port, user, password)
      conn = Bunny.new(:hostname => host, :vhost => vhost, :port => port, :user => user, :password => password)
      conn.start
      ch = conn.create_channel
      #ch.prefetch(1)
      return ch
end


	def ea_translate
	  ch = create_channel(EA_RABBIT_AUTH[:host], EA_RABBIT_AUTH[:vhost], EA_RABBIT_AUTH[:port], EA_RABBIT_AUTH[:user], EA_RABBIT_AUTH[:password])
      q = ch.queue(RABBIT_QUEUES[:ea_payload], durable: true)
      $LOG.info("[*] Waiting for messages on Queue:#{RABBIT_QUEUES[:ea_payload]}. To exit press CTRL+C")

	begin
	  q.subscribe(:manual_ack => true, :block => true) do |delivery_info, properties, body|
	  	$LOG.info("Received: delivery_info:  #{delivery_info}\nproperties:  #{properties}\nbody:  #{body}\n")
	    validator = Validate_XML.new(body)
	   	if validator.check_syntax_error.any?
	   		error_message = validator.get_syntax_error_message
	   		Slack_it.new.bad_ea_intake(body, error_message)
	   		
	   		#publish to EA queue on error payload
	   		Publish_EA.new(properties).error_intake_status(error_message)
	   	else
	   		Slack_it.new.good_ea_intake(body)
	    EA_translate.new.to_haven(body)
	    ch.ack(delivery_info.delivery_tag)
	    $LOG.info("[x] Finished with EA to Haven translation")
		end	
	  end
	    
	rescue Interrupt => _
	  #conn.close
	end	
	end
	


  
end #class end


 # 1.times do |i|
	#   fork do	
	  	EA_Listener.new.ea_translate
	  #EA_Listener.new.full_determination_translator(EA_RABBIT_AUTH[:queue_name])
	  # end
	  # end
	  # Process.waitall





 

