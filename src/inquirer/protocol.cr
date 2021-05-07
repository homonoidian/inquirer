module Inquirer::Protocol
  # Represents a server command.
  #
  # Commands are used to make the Inquirer server fetch or
  # do something.
  enum Command
    # Stops the daemon and the server. Should return status OK.
    Die
    # Checks for connection/existence. Should return status OK.
    Ping
  end

  # Represents an Inquirer server response status.
  enum Status
    Ok
    Err
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

    def self.err
      new(Status::Err)
    end
  end
end
