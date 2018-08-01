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

      $notice_template = "\nContact Email: skywalker@smoodleflux.net\n\nQueue: Account Management Team\n\n\nFrom: Able, Cain [mailto:CAble@smoodleflux.com]\nSent:#{Time.now.strftime("%A, %b %d %Y %l:%M %p")}\nTo:XYZ,Employer(PDQASAP)\nCc:'Leia Organa'\n\n"
      message = $notice_template + notice
      conn = Bunny.new(:hostname => HAVEN_RABBIT_AUTH[:host], :vhost => HAVEN_RABBIT_AUTH[:vhost] , :port => HAVEN_RABBIT_AUTH[:port], :user => HAVEN_RABBIT_AUTH[:user], :password => HAVEN_RABBIT_AUTH[:password])
      conn.start
      channel = conn.create_channel

      exch = channel.topic("X", :auto_delete => false)
      que =  channel.queue(RABBIT_QUEUES[:email], :auto_delete => false, :durable => true).bind(exch, :routing_key => "#")

      EMAILS.each do |email|
      exch.publish(message, :routing_key => "#{email}",  :content_type => "text/plain", :headers => {"Subject" => "Arbitrage: Incomplete/Inconsistent Curam response"})
      end

      puts "sent mail"
      conn.close
    end


end

