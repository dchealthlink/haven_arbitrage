require "bunny"
require './config/secret.rb'
require "./app/helpers/ea_to_haven.rb"
require "./app/validations/xml_validator.rb"
require "./app/notifications/slack_notifier.rb"

class EA_Listener < BaseListener

	def validate_and_notify(body)
		validator = Validate_XML.new(body)
		if validator.check_syntax_error.any?
	   		Slack_it.new.bad_ea_intake(body, validator.get_syntax_error_message)
	   		#publish to queue pending
	   	else
	   		Slack_it.new.good_ea_intake(body)
	end

	def do_translation(body)
		EA_translate.new.to_haven(body)
	end
  
end #class end


 # 1.times do |i|
	#   fork do	
EA_Listener.new.translate(EA_RABBIT_AUTH, RABBIT_QUEUES[:ea_payload], "EA to Haven")
	  #EA_Listener.new.full_determination_translator(EA_RABBIT_AUTH[:queue_name])
	  # end
	  # end
	  # Process.waitall


 # 5.times do |i|
	#   fork do	
	#   Listener.new.pre_determination_translator("Haven_EligibilityResp_RMQ")
	#   end
	#   end
	#   Process.waitall


 
#Listener.new.listen(AUTH[:host], AUTH[:vhost], AUTH[:port], AUTH[:user], AUTH[:password], AUTH[:queue_name])

