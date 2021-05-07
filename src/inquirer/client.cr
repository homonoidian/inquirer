require "json"
require "./protocol"
require "http/client"

module Inquirer
  class Client
    include Protocol

    @@host = "0.0.0.0"
    @@port = 3000

    def self.send(request : Request) : Response
      # This will (hopefully) be a Response from the Inquirer
      # server. We raise InquirerError if it's invalid / is
      # not a Response.
      #
      response = HTTP::Client.post(
        url: "#{@@host}:#{@@port}",
        body: request.to_json,
        headers: HTTP::Headers{
          "User-Agent" => "Inquirer Client",
          "Content-Type" => "application/json"
        }
      )

      content = response.body

      # We assume content is not nil because the server is
      # always right!
      #
      # We assume that `from_json` won't fail for the same
      # exact reason.
      #
      response = Response.from_json(content.not_nil!)

      if response.status.err?
        raise InquirerError.new
      end

      response
    rescue JSON::ParseException
      raise InquirerError.new("server error: wrong response format")
    end

    # Returns whether the Inquirer server is running.
    #
    # NOTE: It sends a Ping command to the server and should
    # not be abused.
    def self.running? : Bool
      # If we get any result, even Status::Invalid, we're
      # still ok.
      #
      !!send Request.new(Command::Ping)
    rescue Socket::ConnectError
      false
    end

    # Sends a request to execute the given *command*.
    #
    # Assumes the server is running.
    #
    # Returns the `Response`.
    #
    # May raise `InquirerError`.
    def self.command(command : Command)
      send Request.new(command)
    end
  end
end
