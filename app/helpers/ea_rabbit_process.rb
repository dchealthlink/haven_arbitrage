require "bunny"
require './config/secret.rb'
require "./app/helpers/ea_to_haven.rb"


class EA_Listener

  include EA_TRANSLATE_MODULE


def create_channel(host, vhost, port, user, password)#, queue_name)
      conn = Bunny.new(:hostname => host, :vhost => vhost, :port => port, :user => user, :password => password)
      conn.start
      ch = conn.create_channel
      #ch.prefetch(1)
      return ch
end


	def ea_translate(queue_name)
	  ch = create_channel(EA_RABBIT_AUTH[:host], EA_RABBIT_AUTH[:vhost], EA_RABBIT_AUTH[:port], EA_RABBIT_AUTH[:user], EA_RABBIT_AUTH[:password])
      q = ch.queue(queue_name, durable: true)
      $LOG.info("[*] Waiting for messages on Queue:#{queue_name}. To exit press CTRL+C")

	begin
	  q.subscribe(:manual_ack => true, :block => true) do |delivery_info, properties, body|
	  	$LOG.info("Received: delivery_info:  #{delivery_info}\nproperties:  #{properties}\nbody:  #{body}\n")
	    translate_ea_to_haven(body.to_s)
	    end
	    ch.ack(delivery_info.delivery_tag)
	    $LOG.info("[x] Done with full_determination_translator")
	rescue Interrupt => _
	  #conn.close
	end	
	end
	


  
end #class end


 1.times do |i|
	  fork do	
	  	EA_Listener.new.ea_translate("sample_IC")
	  #EA_Listener.new.full_determination_translator(EA_RABBIT_AUTH[:queue_name])
	  end
	  end
	  Process.waitall


 # 5.times do |i|
	#   fork do	
	#   Listener.new.pre_determination_translator("Haven_EligibilityResp_RMQ")
	#   end
	#   end
	#   Process.waitall


 
#Listener.new.listen(AUTH[:host], AUTH[:vhost], AUTH[:port], AUTH[:user], AUTH[:password], AUTH[:queue_name])

