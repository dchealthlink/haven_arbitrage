require "sinatra/base"
require "nokogiri"
require "./app/helpers/curam_esb_call"


class MyApp < Sinatra::Base

	# sets root as the parent-directory of the current file
set :root, File.join(File.dirname(__FILE__), '..')
# sets the view directory correctly
set :views, Proc.new { File.join(root, "views") } 

use Rack::Auth::Basic, "Protected Area" do |username, password|
  username == BASIC_AUTH[:user] && password == BASIC_AUTH[:password]
end



  get '/' do
    erb :root
  end

 get '/curam_log' do
 	send_file ("#{Dir.pwd}"+"/log/curam.log")
 end

 get '/ea_log' do
 	send_file ("#{Dir.pwd}"+"/log/ea.log")
 end


 get '/curam_pull' do
	erb :curam_pull
	 curam_pull =  (params['ic'] != nil) ? Curam_ESB_Service.call(params['ic']) : nil
	 @curam_pull = Nokogiri::XML(curam_pull.to_s).to_xml 
	erb :curam_pull		
 end


end