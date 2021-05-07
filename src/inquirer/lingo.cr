module Inquirer
  # Represents a command sent to the Inquirer server and, well,
  # received by the Inquirer server.
  #
  # Commands can be used to make the Inquirer server do/return
  # something, or to make the Inquirer daemon do/return something.
  #
  # The do/return thing depends on the method, e.g. POST and
  # GET, correspondingly.
  enum Command
    # Stops the daemon and the server. Should return status OK.
    Die
    # Checks for connection/existence. Should return status OK.
    Ping
  end

  # Represents an Inquirer response status.
  enum Status
    # Valid data passed.
    Ok
    # Invalid data passed.
    Invalid
  end

  # Represents a request that a client sends to the server.
  struct Request
    include JSON::Serializable

    getter command : Command

    def initialize(@command)
    end

    def to_s(io)
      io << "request to " << @command
    end
  end

  # Represents a response that the server sends to a client.
  struct Response
    include JSON::Serializable

    getter status : Status

    def initialize(@status)
    end

    def to_s(io)
      io << @status << " response"
    end

    def self.ok
      new(Status::Ok)
    end

    def self.invalid
      new(Status::Invalid)
    end
  end
end
