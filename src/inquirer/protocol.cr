module Inquirer::Protocol
  # Represents a server command.
  #
  # Commands are used to make the Inquirer server fetch or
  # do something.
  enum Command
    # Take no argument.

    # Stops the daemon and the server.
    Die = 0
    # Checks for connection/existence.
    Ping

    # Take one argument.

    # Relook at a file. Accepts filepath argument.
    Relook = 2048
    # Regsiters a file.
    Register
    # Unregisters a file.
    Unregister
    # Lists N watchables from the start of the list.
    Watchables

    # Returns whether this command takes one argument.
    def takes_argument?
      self >= Relook
    end
  end

  # Represents Inquirer server response status.
  enum Status
    Ok
    Err
  end

  # A request consisting of a `Command` coupled with an optional
  # string argument of some kind.
  struct Request
    include JSON::Serializable

    # Returns the command of this instruction request.
    getter command : Command
    # Returns the argument of this instruction request.
    getter argument : String

    def initialize(@command, @argument = "")
      if @argument.empty? && @command.takes_argument?
        raise InquirerError.new("this command takes one argument")
      end
    end

    def to_s(io)
      io << command << " " << argument
    end
  end

  # Represents a response that carries the operation status
  # with an optional result alongside.
  struct Response
    include JSON::Serializable

    # Returns the operation status.
    getter status : Status
    # Returns the result.
    getter result : String?

    def initialize(@status, @result = nil)
    end

    def to_s(io)
      io << @status << ": " << @result
    end

    # Makes an ok response.
    def self.ok(*args)
      Response.new(Status::Ok, *args)
    end

    # Makes an error response.
    def self.err(*args)
      Response.new(Status::Err, *args)
    end
  end
end
