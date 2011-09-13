# An example of using Patchbay as a standalone app.
require './patchbay'

class MyRackApp < Patchbay
    get '/' do
        render :html => "<html><body>Hello World!</body></html>"
    end

    get '/goodbye' do
        render :html => "<html><body>Goodbye, have fun at RPI TV</body></html>"
    end

    get '/say/:value' do
        render :html => "<html><body>#{params[:value]}</body></html>"
    end
end


use Rack::CommonLogger

run MyRackApp.new
