require 'rack/mime'
require 'rack/handler'

# The main Patchbay class, from which application classes derive.
class Patchbay

    NoRoute_Message = <<EOT
<html><body>
<h1>404</h1><p>Patchbay: Routing Error</p>
</body></html>
EOT

    Forbidden_Message = <<EOT
<html><body>
<h1>403</h1>
<p>Forbidden</p>
</body></html>
EOT

    Exception_Message = <<EOT
<html><body>
<h1>500</h1>
<p>Internal Server Error</p>
</body></html>
EOT

private
    # Checks if the `path_to_test` falls within the `root_path`.
    # This can be used to test for directory-traversal attacks.
    #
    # @param [String] path_to_test A path which is to be checked against the root path.
    # @param [String] root_path A path that `path_to_test` will be checked against.
    # @return [Boolean] True if the `path_to_test` is within the `root_path`, false otherwise.
    def path_is_subdir_of(path_to_test, root_path)
        File.fnmatch(File.join(root_path, '**'), File.realpath(path_to_test))
    end

    # Parses URLs and matches them to handlers.
    #
    class Router        
        # Wrap up data associated with a route.
        class Route < Struct.new(:handler, :url_parts, :verb)
        end

        def initialize
            @routes = []
        end

        private

        # Check if the given route data matches the split-up URL.
        #
        # == Parameters:
        # route::
        #   An object that responds to `handler`, `url_parts`, and `verb`.
        #
        # url_parts::
        #   An array of Strings corresponding to a split URL.
        #
        def matches?(route, url_parts)
            if route.url_parts.size != url_parts.size
                return false
            end

            params = { }

            route.url_parts.zip(url_parts) do |parts|
                route_url_part = parts[0]
                url_part = parts[1]

                if route_url_part =~ /:(.+)/
                    params[$1.intern] = url_part
                else
                    if route_url_part != url_part
                        return false
                    end
                end
            end

            return params
        end

        public

        # Find a handler matching an HTTP request.
        #
        # == Parameters:
        # verb::
        #   The HTTP verb (GET, POST etc)
        # url::
        #   The requested URL
        #
        # == Returns:
        # A 2-element array consisting of the handler
        # followed by a hash of parameters extracted from the URL.
        #
        def match(verb, url)
            parts = url.gsub(/^\/+/,'').split('/')

            @routes.each do |route|
                if route.verb == verb
                    result = matches?(route, parts)
                    if result
                        return [ route.handler, result ]
                    end
                end
            end

            return [ nil, nil ]
        end

        # Add a route matching a certain URL pattern and verb.
        #
        # == Parameters:
        # verb::
        #   The HTTP verb (GET, POST etc)
        # route::
        #   The URL template to match.
        #   This may contain symbols of the form `:xxxx`;
        #   these represent variable parameters to be extracted from the URL
        #   when it is matched.
        def add(verb, route, handler)
            parts = route.gsub(/^\/+/,'').split('/')
            routeObj = Route.new
            routeObj.url_parts = parts
            routeObj.handler = handler
            routeObj.verb = verb
            @routes << routeObj
        end
    end

protected
    def self.router
        @router ||= Router.new
        @router
    end

    def router
        self.class.router
    end

public
    # Set up a handler for GET requests matching a given route.
    #
    # == Parameters:
    # route: 
    #   Route pattern to match (see Patchbay::Router::add)
    # action:
    #   Block to be executed to fulfill the request
    #
    def self.get(route, &action)
        router.add('GET', route, action)
    end

    # Set up a handler for PUT requests matching a given route.
    #
    # == Parameters:
    # route: 
    #   Route pattern to match (see Patchbay::Router::add)
    # action:
    #   Block to be executed to fulfill the request
    #
    def self.put(route, &action)
        router.add('PUT', route, action)
    end

    # Set up a handler for POST requests matching a given route.
    #
    # == Parameters:
    # route: 
    #   Route pattern to match (see Patchbay::Router::add)
    # action:
    #   Block to be executed to fulfill the request
    #
    def self.post(route, &action)
        router.add('POST', route, action)
    end

    # Set up a handler for DELETE requests matching a given route.
    #
    # == Parameters:
    # route: 
    #   Route pattern to match (see Patchbay::Router::add)
    # action:
    #   Block to be executed to fulfill the request
    #
    def self.delete(route, &action)
        router.add('DELETE', route, action)
    end

    # Get directory from which static files are being served
    #
    # == Returns:
    # The absolute path to the directory from which static files
    # may be served.
    #
    def self.files_dir
        @files_dir
    end

    # Set directory from which static files may be served
    #
    # == Parameters:
    # new_dir:
    #   Path (relative or absolute) from which static files may
    #   be served.
    def self.files_dir=(new_dir)
        @files_dir = File.realpath(new_dir)
    end

    # Convenience function for accessing files_dir without writing 
    # self.class.files_dir
    #
    def files_dir
        self.class.files_dir
    end

public
    # Get the Rack environment corresponding to the current request.
    #
    # == Returns:
    # The Rack environment corresponding to the ongoing request.
    #
    def environment
        @environment
    end

    # Get the parameters parsed from the request URL.
    #
    # == Returns:
    # A Hash-like object representing the passed parameters.
    #
    def params
        @params
    end

private
    # Handle requests that match no route, when we have a public files directory.
    # Sets up the response appropriately for that case.
    #
    # == Returns:
    # None.
    #
    def handle_file
        url_parts = environment['PATH_INFO'].split('/')
        file_path = File.join(files_dir, url_parts)

        if File.exists?(file_path) and path_is_subdir_of(file_path, files_dir)
            if File.readable?(file_path)
                send_file(file_path)
            else
                handle_forbidden
            end
        elsif File.exists?(file_path)
            handle_no_route
        else
            handle_no_route
        end
    end

    # Set up the response to send a file once its absolute path is known.
    #
    def send_file(file_path)
        mime_type = Rack::Mime.mime_type(File.extname(file_path))
        @response = [200, { "Content-Type" => mime_type }, File.new(file_path)]
    end

public
    # Rack callable interface.
    #
    # == Returns:
    # A 3-element array of [status, response_headers, body].
    #
    def call(env)
        # find a handler for this request
        handler, route_params = router.match(env['REQUEST_METHOD'], env['PATH_INFO'])

        @params = route_params

        @environment = env
        
        @response = nil

        begin
            if handler
                self.instance_eval(&handler)
            else
                if files_dir
                    handle_file
                else
                    handle_no_route
                end
            end

            unless @response
                fail "No response was generated" 
            end
        rescue Exception => e
            handle_exception(e)
        end

        @response
    end

private
    # Set response content and type.
    #
    # == Parameters:
    # options::
    #   A Hash of parameters.
    #   `:error => 404`: set response error code
    #   `:html => '<html>...</html>'`, `:json => '{...}'` etc: set response content and content type.
    #    Content type is guessed automatically.
    #
    def render(options={})
        if @response
            fail "can only render once per request"
        end

        @response = [200, { "Content-Type" => "text/html" }, []]
        options.each do |key, value|
            case key
                when :error, :status
                    @response[0] = value
                else
                    @response[1]["Content-Type"] = Rack::Mime.mime_type("."+key.to_s)
                    @response[2] << value
            end
        end
    end

    # Set up response for 404 (route/page not found) error.
    #
    def handle_no_route
        @response = [404, { "Content-Type" => "text/html" }, [NoRoute_Message]]
    end

    # Handle exceptions occurring during route-handler execution.
    #
    def handle_exception(e)
        @response = [500, { "Content-Type" => "text/html" }, [Exception_Message]]
        $stderr.puts e.inspect
        e.backtrace.each { |bt| $stderr.puts bt }
    end

    # Set up response when permission was denied attempting to read a local file.
    #
    def handle_forbidden
        @response = [403, { "Content-Type" => "text/html" }, [Forbidden_Message]]
    end

public
    # Start an appropriate server to run the application.
    #
    # == Parameters:
    # options::
    #   Options hash to be passed to the Rack handler.
    def run(options={})
        handler = find_rack_handler
        handler_name = handler.name.gsub(/.*::/,'')
        $stderr.puts "Patchbay starting, using #{handler_name}"
        handler.run(self, options)
    end

private
    # Search through installed Rack handlers for ones we like
    #
    def find_rack_handler
        servers = %w/thin mongrel webrick/
        servers.each do |server|
            begin
                return Rack::Handler.get(server)
            rescue LoadError
            end
        end
    end
end
