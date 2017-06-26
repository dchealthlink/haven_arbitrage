# require 'logger'

# desc "Start Rabbit Haven_ICID_RMQ" 

# task :Haven_ICID_RMQ do
# 	require "./app/helpers/translate.rb"


# #Dir.chdir("./app/helpers")
# #puts Dir.pwd
# #require "#{Dir.pwd}" + "/translate.rb"
# Listener.new.full_determination_translator("Haven_ICID_RMQ")
# 	 #  1.times do |i|
# 	 #  fork do	
# 	 # #	Listener.new.full_determination_translator("Haven_ICID_RMQ") #{}"#{sh "ruby app/helpers/listener.rb &>> log/log_file.log"}"
# 	 #  end
# 	 #  end
# 	 #  Process.waitall
# end


desc "Start Rabbit Haven_ICID_RMQ" 
task :start_arbitrage do	
	  sh "ruby app/helpers/translate.rb"	  
end