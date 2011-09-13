# An example of Patchbay embedded inside another program.
require 'rubygems'
require './patchbay'

class MyApp < Patchbay
    get '/' do
        render :html => "<html><body>Hello World!</body></html>"
    end

    get '/goodbye' do
        render :html => "<html><body>Goodbye</body></html>"
    end

    get '/say/:value' do
        render :html => "<html><body>#{params[:value]}</body></html>"
    end

    get '/something' do
        render :html => "<html><body>#{@something}</body></html>"
    end 

    attr_accessor :something
end


app = MyApp.new
Thread.new { app.run(:Host => "::0", :Port => "3000") }

ARGF.each_line do |line|
    app.something = line
end

