require "bunny"

module Publish

UAT_AUTH = { host: "xxxxxx", vhost: "/", port: "5672", user: "xxxx", password: "xxxxx", queue_name: "Haven_ICID_RMQ"}
	def self.arbitrageResp_RMQ(host, vhost, port, user, password, queue_name, message)
	  conn = Bunny.new(:hostname => host, :vhost => vhost, :port => port, :user => user, :password => password)
      conn.start
      channel = conn.create_channel
      queue    = channel.queue(queue_name, :durable => true)
      queue.publish(message, :persistant => true)
      conn.close
    end


    def email_notice(message)

      conn = Bunny.new(:hostname => UAT_AUTH[:host], :vhost => UAT_AUTH[:vhost] , :port => UAT_AUTH[:port], :user => UAT_AUTH[:user], :password => UAT_AUTH[:password])
      conn.start
      channel = conn.create_channel

      exch = channel.topic("X", :auto_delete => false)
      que =  channel.queue("email-out", :auto_delete => false, :durable => true).bind(exch, :routing_key => "#")

      exch.publish(message, :routing_key => "venumadhav.dondapati@dc.gov",  :content_type => "text/plain", :headers => {"Subject" => "Arbitrage: Incomplete/Inconsistent Curam response"})
     # exch.publish(message, :routing_key => "Dan.Northrup3@dc.gov",  :content_type => "text/plain", :headers => {"Subject" => "Arbitrage: Incomplete/Inconsistent Curam response"})
      #exch.publish(message, :routing_key => "thomas.fahey@dc.gov",  :content_type => "text/plain", :headers => {"Subject" => "Arbitrage: Incomplete/Inconsistent Curam response"})
      exch.publish(message, :routing_key => "nitishranjan.patil@dc.gov",  :content_type => "text/plain", :headers => {"Subject" => "Arbitrage: Incomplete/Inconsistent Curam response"})
     # exch.publish(message, :routing_key => "james.butler6@dc.gov",  :content_type => "text/plain", :headers => {"Subject" => "Arbitrage: Incomplete/Inconsistent Curam response"})
      exch.publish(message, :routing_key => "thomas.fahey@dc.gov",  :content_type => "text/plain", :headers => {"Subject" => "Arbitrage: Incomplete/Inconsistent Curam response"})

      puts "sent mail"
      conn.close
    end
end


#Publish.email_notice("Testing multiple routing messages")
#thomas.fahey@dc.gov
#venumadhav.dondapati@dc.gov

#:routing_key => "venumadhav.dondapati@dc.gov",