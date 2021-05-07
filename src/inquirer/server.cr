require "json"
require "kemal"
require "./protocol"

# Inquirer's server.
#
# Inquirer communicates with Ven (and Ven communicates with
# Inquirer) through Orchestra, which itself sends & receives
# requests from and to the Inquirer server.
#
# The Inquirer server is a simple RESTful API that acceps
# JSON requests and sends JSON responses.
#
# A simple status page is also provided: users can inspect
# the scanned Ven distincts by navigating to this page.
#
# Powered by Kemal.
module Inquirer
  class Server
    include Protocol

    # Makes a Server.
    #
    # *daemon* is the daemon that started this server and
    # that is controlled by this server.
    def initialize(@daemon : Daemon)
    end

    # Executes a Request.
    def execute(request : Request)
      Console.progress("Executing: #{request}")

      case request.command
      in .die?
        # Wait for a second so we can send the OK response.
        #
        spawn @daemon.stop(wait: 1.second)
      in .ping?
        # pass
      end

      # Invalid stuff cannot get down here, so we're sure
      # we're ok.
      #
      Response.ok
    rescue JSON::ParseException
      Response.err
    end

    # Defines all routes.
    #
    # Currently, those are:
    #   - `POST /` Executes a command.
    private def route!
      # Dispatches to execute().
      #
      post "/" do |env|
        env.response.content_type = "application/json"

        content = env.request.body.try(&.gets_to_end)

        # Be graceful even on syntax errors!
        #
        response =
          if content.nil? || content.empty?
            Response.err
          else
            begin
              execute Request.from_json(content)
            rescue JSON::ParseException
              Response.err
            end
          end

        response.to_json
      end
    end

    # Starts listening on the given *port*.
    def listen(port : Int32 = 3000)
      route!

      Kemal.run(port, args: nil) do |config|
        Kemal.config.shutdown_message = false
      end
    end
  end
end
