require "json"
require "kemal"
require "./protocol"

module Inquirer
  class Server
    include Protocol

    # Makes a Server from the given *config* and *daemon*,
    # which the new server will look after.
    def initialize(@config : Config, @daemon : Daemon)
    end

    # Executes the given *request*. Returns the appropriate
    # `Response`.
    def execute(request : Request)
      Console.log("Executing #{request}")

      case request.command
      in .ls?
        # TODO: transmit them to the client
        puts @daemon.watchables[...100].join("\n")
      in .die?
        # So there is time to send the OK response to the client
        # that requested the death.
        spawn @daemon.stop(wait: 1.second)
      in .ping?
        # pass
      end

      # Invalid stuff cannot get down here, so we're sure
      # all is ok.
      Response.ok
    end

    # Parses the given JSON *query* and formulates a proper
    # `Protocol::Response`.
    def respond_to(query : String?) : Response
      begin
        unless query.nil? || query.empty?
          return execute Request.from_json(query)
        end
      rescue JSON::ParseException
        # pass
      end

      Response.err
    end

    # Starts serving the Inquirer API.
    def serve
      post "/" do |env|
        env.response.content_type = "application/json"
        query = env.request.body.try(&.gets_to_end)
        response = respond_to(query)
        response.to_json
      end

      Kemal.run(@config.port, args: nil) do |config|
        Kemal.config.shutdown_message = false
      end
    end
  end
end
