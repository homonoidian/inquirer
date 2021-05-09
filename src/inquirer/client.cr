require "json"
require "./protocol"
require "http/client"

module Inquirer
  class Client
    include Protocol

    def initialize(@config : Config)
    end

    # Sends the given *request* to the Inquirer server.
    #
    # Raises `InquirerError` if the server did not respond.
    def send(request : Request) : Response
      response = HTTP::Client.post(
        url: "0.0.0.0:#{@config.port}",
        body: request.to_json,
        headers: HTTP::Headers{
          "User-Agent" => "Inquirer Client",
          "Content-Type" => "application/json"
        }
      )

      unless body = response.body
        raise InquirerError.new("server error: empty response")
      end

      Response.from_json(body)
    end

    # Asserts the server is running.
    #
    # If assertion failed and *exit* is true, uses `Console.exit`;
    # otherwise, uses `Console.error`.
    #
    # If assertion succeeded, returns self.
    def running!(exit = false)
      unless running?
        if exit
          Console.exit(1,
            "assertion failed: server is not running " \
            " on port #{@config.port}")
        else
          Console.error(
            "assertion failed: server is not running " \
            " on port #{@config.port}")
        end
      end

      self
    end

    # Returns whether the server is running.
    def running? : Bool
      !!command(Command::Ping)
    rescue Socket::ConnectError
      false
    end

    # Sends a request to execute the given *command*.
    #
    # Assumes the server is running.
    def command(command : Command) : Response
      send Request.new(command)
    end

    # Makes a client from the given *config*.
    def self.from(config : Config)
      new(config)
    end
  end
end
