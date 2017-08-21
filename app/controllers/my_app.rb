require "sinatra/base"



class MyApp < Sinatra::Base

	# sets root as the parent-directory of the current file
set :root, File.join(File.dirname(__FILE__), '..')
# sets the view directory correctly
set :views, Proc.new { File.join(root, "views") } 


  get '/' do
    "Welcome to Translation world.........!"
  end

 # run!

 get '/curam_log' do
 	send_file ("#{Dir.pwd}"+"/log/curam.log")
 end

 get '/ea_log' do
 	send_file ("#{Dir.pwd}"+"/log/ea.log")
 end

 get '/log' do
  erb :log
 end

end