require "bunny"
require './config/secret.rb'
require "./app/helpers/ea_to_haven.rb"
require 'JSON'

class Mobile_Listener < BaseListener

    def validate_and_notify(body)
		#TODO validation
		begin
			Slack_it.new.mobile_intake(JSON.parse(body))
		rescue Exception => e 
			Slack_it.new.mobile_intake_error(body, e)
		end
	end

	def do_translation(body)
		MobileTranslator.new.to_haven(body)
	end
  
end #class end


 # 1.times do |i|
	#   fork do	
Mobile_Listener.new.translate(HAVEN_RABBIT_AUTH, RABBIT_QUEUES[:mobile_payload], "Mobile to Haven")
	  #EA_Listener.new.full_determination_translator(EA_RABBIT_AUTH[:queue_name])
	  # end
	  # end
	  # Process.waitall


