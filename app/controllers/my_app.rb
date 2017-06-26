require "sinatra/base"


class MyApp < Sinatra::Base
  get '/' do
    "Welcome to Arbitrage.........!"
  end

 # run!
end