require "json"
require "./protocol"
require "http/client"

module Inquirer
  # Contains many useful utilities & primitives for communicating
  # with the Inquirer server/daemon.
  class Client
    include Protocol

    # Makes a client from the given Inquirer *config*, and with
    # a *host* to connect to (defaults to localhost-ish).
    def initialize(@config : Config, @host = "0.0.0.0")
    end

    # Sends raw *request* to the server.
    #
    # Raises `InquirerError` if the server did not respond
    # properly (and the socket error if it did not repond
    # at all).
    def send(request : Request) : Response
      response = HTTP::Client.post(
        url: "#{@host}:#{@config.port}",
        body: request.to_json,
        headers: HTTP::Headers{
          "User-Agent"   => "Inquirer Client",
          "Content-Type" => "application/json",
        }
      )

      unless body = response.body
        raise InquirerError.new("server error: empty response")
      end

      Response.from_json(body)
    end

    # Asserts the server is running.
    #
    # Reports failure of that assertion using `Console.exit`
    # if *exit* is true, otherwise using `Console.error`.
    #
    # If assertion succeeded, returns self.
    def running!(exit = false)
      unless running?
        if exit
          Console.exit(1,
            "assertion failed: server is not running " \
            "on port #{@config.port}")
        else
          Console.error(
            "assertion failed: server is not running " \
            "on port #{@config.port}")
        end
      end

      self
    end

    # Returns whether the server is running.
    #
    # Sends a `Command::Ping` command and checks if the response
    # result is `"pong"`. If it is, the Inquirer server this
    # client is connected to is indeed running.
    def running? : Bool
      command(Command::Ping).result == "pong"
    rescue Socket::ConnectError
      false
    end

    # Sends a request to execute a *command*.
    #
    # Assumes (and does not check) that the server is running.
    def command(command : Command) : Response
      send Request.new(command)
    end

    # Makes a client from the given Inquirer *config*.
    def self.from(config : Config)
      new(config)
    end
  end
end
