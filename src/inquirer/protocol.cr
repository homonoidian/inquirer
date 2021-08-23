module Inquirer::Protocol
  # Represents Inquirer server command.
  #
  # Commands are used to make the server fetch or do something.
  enum Command
    # Stops the daemon and the server.
    Die = 0
    # Checks whether the server is running and whetber it is
    # the correct server.
    Ping
    # Returns the repository.
    Repo
    # Returns all commands of the server.
    Commands

    # Lists N directories out of those that are currently
    # watched.
    Ps = 2048
    # Relooks at a Ven program given an absolute path to the
    # source file of the program.
    Relook
    # Removes all mentions of the given source file from
    # the repository.
    Purge
    # Returns which files to run in order to load the
    # given distinct, with the origin directory being
    # the root directory of each filepath.
    FilesFor
    # Returns the source code for the given filename in
    # the origin directory.
    SourceFor

    # Returns whether this command takes an argument.
    def takes_argument?
      self >= Ps
    end
  end

  # Represents Inquirer server response status.
  #
  # The server uses it to tell whether an operation succeeded.
  enum Status
    Ok
    Err
  end

  # A request consisting of a `Command` plus an optional
  # string argument of some kind.
  struct Request
    include JSON::Serializable

    # Returns the command of this request.
    getter command : Command
    # Returns the argument of this request.
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

  # Represents a response that carries a `Status` plus an
  # optional result of some kind.
  struct Response
    include JSON::Serializable

    private alias RType = Hash(String, Array(String)) | Array(String) | String

    # Returns the status.
    getter status : Status
    # Returns the result.
    getter result : RType?

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
