require "bunny"
require './config/secret.rb'
require "./app/helpers/publish"
require "./app/helpers/EA_Response_builder"
require "./app/helpers/curam_to_havendb"
require "./app/helpers/curam_esb_call.rb"


class Listener

# files = Dir["#{File.dirname(__FILE__)}/*.rb"]
# files.delete("app/helpers/translate.rb")
# files.each {|file| require "./#{file}" }
  include Curam_ESB_Service
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
	  ch = create_channel(HAVEN_RABBIT_AUTH[:host], HAVEN_RABBIT_AUTH[:vhost], HAVEN_RABBIT_AUTH[:port], HAVEN_RABBIT_AUTH[:user], HAVEN_RABBIT_AUTH[:password])
      q = ch.queue(queue_name, durable: true)
      $LOG.info("[*] Waiting for messages. To exit press CTRL+C")

	begin
	  q.subscribe(:manual_ack => true, :block => true) do |delivery_info, properties, body|
	  	$LOG.info("Received: delivery_info:  #{delivery_info}\nproperties:  #{properties}\nbody:  #{body}\n")
	    ic = body.scan(/\b\d{7}\b/)[0]
	    curam_response = Curam_ESB_Service.call(ic)
	    $LOG.info("Curam response for #{ic}:\n #{curam_response.inspect}")
	    complete = store_to_haven_db(curam_response)
	    consistent = curam_inconsistent_app_check(curam_response)
	    if ( complete && consistent )

	    	puts "***********************Hurray validations success******************************"
	    EA_Response_builder.call_haven(curam_response)
	    end
	    ch.ack(delivery_info.delivery_tag)
	    $LOG.info("[x] Finshed with Curam XML translation")
	    end
	rescue Interrupt => _
	  #conn.close
	end	
	end


end


 # 1.times do |i|
	#   fork do	
	  Listener.new.full_determination_translator(RABBIT_QUEUES[:curam_ic])
	  # end
	  # end
	  # Process.waitall

