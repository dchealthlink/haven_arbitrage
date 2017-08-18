require "sinatra/base"



class MyApp < Sinatra::Base

	# sets root as the parent-directory of the current file
set :root, File.join(File.dirname(__FILE__), '..')
# sets the view directory correctly
set :views, Proc.new { File.join(root, "views") } 


  get '/' do
    "Welcome to Arbitrage.........!"
  end

 # run!

 get '/curam_log' do
 	@log = File.read("#{Dir.pwd}"+"/log/log_file.log")
 	erb :view_log
 end

 get '/ea_log' do
 @log =  File.read("#{Dir.pwd}"+"/log/log_file.log")
 	erb :view_log
 end

end