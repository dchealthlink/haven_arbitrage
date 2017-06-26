require "bunny"
require './config/secret.rb'
require "./app/helpers/publish"
require "./app/helpers/EA_Response_builder"
require "./app/helpers/curam_to_havendb"
require "./app/helpers/web_services"


class Listener

# files = Dir["#{File.dirname(__FILE__)}/*.rb"]
# files.delete("app/helpers/translate.rb")
# files.each {|file| require "./#{file}" }
  include Web_Services
  include Publish
  include Store
  include EA_Response_builder


def create_channel(host, vhost, port, user, password)#, queue_name)
      conn = Bunny.new(:hostname => host, :vhost => vhost, :port => port, :user => user, :password => password)
      conn.start

      ch = conn.create_channel
      #ch.prefetch(1)
      return ch

end


	def full_determination_translator(queue_name)
	  ch = create_channel(AUTH[:host], AUTH[:vhost], AUTH[:port], AUTH[:user], AUTH[:password])
      q = ch.queue(queue_name, durable: true)
      $LOG.info("[*] Waiting for messages. To exit press CTRL+C")

	begin
	  q.subscribe(:manual_ack => true, :block => true) do |delivery_info, properties, body|
	  	$LOG.info("Received: delivery_info:  #{delivery_info}\nproperties:  #{properties}\nbody:  #{body}\n")
	    ic = body.scan(/\b\d{7}\b/)[0]
	    curam_response = Web_Services.curam(ic).to_xml
	    $LOG.info("Curam response for #{ic}:\n #{curam_response.inspect}")
	    complete = store_to_haven_db(curam_response)
	    consistent = curam_inconsistent_app_check(curam_response)
	    if ( complete && consistent )

	    	puts "***********************Hurray validations success******************************"
	    EA_Response_builder.call_haven(curam_response)
	    #Publish.arbitrageResp_RMQ(AUTH[:host], AUTH[:vhost], AUTH[:port], AUTH[:user], AUTH[:password], "HavenICPayload_Request_RMQ", EA_Response_builder.call_haven(curam_response))
	    end
	    ch.ack(delivery_info.delivery_tag)
	    $LOG.info("[x] Done with full_determination_translator")
	    end
	rescue Interrupt => _
	  #conn.close
	end	
	end
	
   def pre_determination_translator(queue_name)
	  ch = create_channel(AUTH[:host], AUTH[:vhost], AUTH[:port], AUTH[:user], AUTH[:password])
      q = ch.queue(queue_name, durable: true)
      $LOG.info("[*] Waiting for messages. To exit press CTRL+C")

	begin
	  q.subscribe(:manual_ack => true, :block => true) do |delivery_info, properties, body|
	    $LOG.info("Received: delivery_info:  #{delivery_info}\nproperties:  #{properties}\nbody:  #{body}\n")
	    Publish.arbitrageResp_RMQ(AUTH[:host], AUTH[:vhost], AUTH[:port], AUTH[:user], AUTH[:password], "HavenICPayload_Request_RMQ", EA_Response_builder.build_response(body))
	    $LOG.info("[x] Done with pre_determination_translator")
	    ch.ack(delivery_info.delivery_tag)
	    end
	rescue Interrupt => _
	  #conn.close
	end	
	end


end


 5.times do |i|
	  fork do	
	  Listener.new.full_determination_translator("sample_IC")
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

