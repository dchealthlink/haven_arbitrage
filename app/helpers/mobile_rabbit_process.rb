require "bunny"
require './config/secret.rb'
require "./app/helpers/ea_to_haven.rb"

class Mobile_Listener


def create_channel(host, vhost, port, user, password)
      conn = Bunny.new(:hostname => host, :vhost => vhost, :port => port, :user => user, :password => password)
      conn.start
      ch = conn.create_channel
      #ch.prefetch(1)
      return ch
end


	def mobile_payload_translate(queue_name)
	  ch = create_channel(HAVEN_RABBIT_AUTH[:host], HAVEN_RABBIT_AUTH[:vhost], HAVEN_RABBIT_AUTH[:port], HAVEN_RABBIT_AUTH[:user], HAVEN_RABBIT_AUTH[:password])
      q = ch.queue(queue_name, durable: true)
      $LOG.info("[*] Waiting for messages on Queue:#{queue_name}. To exit press CTRL+C")

	begin
	  q.subscribe(:manual_ack => true, :block => true) do |delivery_info, properties, body|
	  	$LOG.info("Received: delivery_info:  #{delivery_info}\nproperties:  #{properties}\nbody:  #{body}\n")
	    EA_translate.new.translate_ea_to_haven(body.to_s)
	    end
	    ch.ack(delivery_info.delivery_tag)
	    $LOG.info("[x] Done with Mobile to Haven translation\n\n******Come on...! I would expect some claps....Thank you *******")
	rescue Interrupt => _
	  #conn.close
	end	
	end
	


  
end #class end


 # 1.times do |i|
	#   fork do	
	  	Mobile_Listener.new.mobile_payload_translate(RABBIT_QUEUES[:mobile_payload])
	  #EA_Listener.new.full_determination_translator(EA_RABBIT_AUTH[:queue_name])
	  # end
	  # end
	  # Process.waitall


