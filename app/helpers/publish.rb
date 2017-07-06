require "bunny"
require './config/secret.rb'

module Publish

# Wrong credentials to bunny.new
	# def self.arbitrageResp_RMQ(host, vhost, port, user, password, queue_name, message)
	#   conn = Bunny.new(:hostname => HAVEN_RABBIT_AUTH[:host], :vhost => HAVEN_RABBIT_AUTH[:vhost], :port => HAVEN_RABBIT_AUTH[:port], :user => HAVEN_RABBIT_AUTH[:user], :password => HAVEN_RABBIT_AUTH[:password])
 #      conn.start
 #      channel = conn.create_channel
 #      queue    = channel.queue(queue_name, :durable => true)
 #      queue.publish(message, :persistant => true)
 #      conn.close
 #    end


     def email_notice(notice)

      $notice_template = "\nContact Email: desha@washingtondoor.net\n\nQueue: Account Management Team\n\n\nFrom: Kane, Meghan [mailto:MKane@kellyway.com]\nSent:#{Time.now.strftime("%A, %b %d %Y %l:%M %p")}\nTo:HBX,Employer(DCHBX)\nCc:'Tracey Elwood'\n\n"
      message = $notice_template + notice
      conn = Bunny.new(:hostname => HAVEN_RABBIT_AUTH[:host], :vhost => HAVEN_RABBIT_AUTH[:vhost] , :port => HAVEN_RABBIT_AUTH[:port], :user => HAVEN_RABBIT_AUTH[:user], :password => HAVEN_RABBIT_AUTH[:password])
      conn.start
      channel = conn.create_channel

      exch = channel.topic("X", :auto_delete => false)
      que =  channel.queue(RABBIT_QUEUES[:email], :auto_delete => false, :durable => true).bind(exch, :routing_key => "#")

      #exch.publish(message, :routing_key => "venumadhav.dondapati@dc.gov",  :content_type => "text/plain", :headers => {"Subject" => "Arbitrage: Incomplete/Inconsistent Curam response"})
      #exch.publish(message, :routing_key => "Dan.Northrup3@dc.gov",  :content_type => "text/plain", :headers => {"Subject" => "Arbitrage: Incomplete/Inconsistent Curam response"})
      exch.publish(message, :routing_key => "george.gluck@dc.gov",  :content_type => "text/plain", :headers => {"Subject" => "Arbitrage: Incomplete/Inconsistent Curam response"})
      #exch.publish(message, :routing_key => "nitishranjan.patil@dc.gov",  :content_type => "text/plain", :headers => {"Subject" => "Arbitrage: Incomplete/Inconsistent Curam response"})
      #exch.publish(message, :routing_key => "james.butler6@dc.gov",  :content_type => "text/plain", :headers => {"Subject" => "Arbitrage: Incomplete/Inconsistent Curam response"})
      #exch.publish(message, :routing_key => "thomas.fahey@dc.gov",  :content_type => "text/plain", :headers => {"Subject" => "Arbitrage: Incomplete/Inconsistent Curam response"})

      puts "sent mail"
      conn.close
    end
end


#Publish.email_notice("Testing multiple routing messages")
#thomas.fahey@dc.gov
#venumadhav.dondapati@dc.gov

#:routing_key => "venumadhav.dondapati@dc.gov",