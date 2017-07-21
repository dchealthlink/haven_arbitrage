require "bunny"
require './config/secret.rb'
require "./app/helpers/ea_to_haven.rb"
require "./app/validations/xml_validator.rb"
require "./app/notifications/slack_notifier.rb"

class BaseListener
  def create_channel(host, vhost, port, user, password)
        conn = Bunny.new(:hostname => host, :vhost => vhost, :port => port, :user => user, :password => password)
        conn.start
        ch = conn.create_channel
        #ch.prefetch(1)
        return ch
  end

  def translate(auth, queue_name, translation_desc)
    ch = create_channel(auth[:host], auth[:vhost], auth[:port], auth[:user], auth[:password])
      q = ch.queue(queue_name, durable: true)
      $LOG.info("[*] Waiting for messages on Queue:#{queue_name}. To exit press CTRL+C")

    begin
      q.subscribe(:manual_ack => true, :block => true) do |delivery_info, properties, body|
        $LOG.info("Received: delivery_info:  #{delivery_info} \nproperties:  #{properties}\nbody:  #{body}\n")
        
        validate_and_notify(body)
        do_translation(body)
  
        ch.ack(delivery_info.delivery_tag)
        $LOG.info("[x] Finished with #{translation_desc} translation")
      end 
    rescue Interrupt => _
      #conn.close
    end 
  end

end