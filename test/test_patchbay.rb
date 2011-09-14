require 'test/unit'
require 'patchbay'
require 'rack/test'

class PatchbayTestApp < Patchbay
    get '/' do
        render :html => 'Hello World'
    end

    post '/' do
        render :html => 'post'
    end

    put '/' do
        render :html => 'put'
    end

    delete '/' do
        render :html => 'delete'
    end

    get '/something.json' do
        render :json => '{1:2}'
    end

    get '/image.jpg' do
        render :jpg => '<jpeg data here>'
    end
end

class PatchbayTestAppWithFiles < Patchbay
    self.files_dir = 'test/fixtures/files_allowed'

    get '/authorized_users_only' do
        send_file('test/fixtures/files_not_allowed/passwd.txt')
    end
end

class PatchbayTest < Test::Unit::TestCase
    include Rack::Test::Methods
    def app
        @app ||= PatchbayTestApp.new
        @app
    end

    def test_html_render
        get '/'
        assert_equal 'Hello World', last_response.body
        assert_equal 'text/html', last_response.headers["Content-Type"]
        assert_equal 200, last_response.status
    end

    def test_methods
        # verify that different HTTP verbs are routed to their correct
        # request handlers
        get '/'
        assert_equal 'Hello World', last_response.body

        post '/'
        assert_equal 'post', last_response.body

        put '/'
        assert_equal 'put', last_response.body
        
        delete '/'
        assert_equal 'delete', last_response.body
    end

    def test_json_render
        get '/something.json'
        assert_equal 'application/json', last_response.headers["Content-Type"]
        assert_equal 200, last_response.status
    end

    def test_jpg_render
        get '/image.jpg'
        assert_equal 'image/jpeg', last_response.headers["Content-Type"]
    end

    def test_routing_error
        get '/something_that_doesnt_exist'
        assert_equal 404, last_response.status
    end
end

class PatchbayWithFilesTest < Test::Unit::TestCase
    include Rack::Test::Methods

    def app
        @app ||= PatchbayTestAppWithFiles.new
        @app
    end

    def test_can_get_files
        get '/test.txt'
        assert last_response.body.include?('this file is supposed to be here')
        assert_equal 'text/plain', last_response.headers["Content-Type"]

        get '/test.jpg'
        assert_equal 'image/jpeg', last_response.headers["Content-Type"]
    end

    def test_cannot_traverse_directories
        get '/../files_not_allowed/passwd.txt'
        assert_equal 404, last_response.status
    end

    def test_can_send_file
        get '/authorized_users_only'
        assert last_response.body.include?('SUPER SECRET PASSWORDS')
        assert_equal 200, last_response.status
    end
end
