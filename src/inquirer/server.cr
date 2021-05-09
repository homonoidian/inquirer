require "json"
require "kemal"
require "./protocol"

module Inquirer
  class Server
    include Protocol

    # Makes a Server from the given *config*.
    #
    # *daemon* is the daemon that the new server will
    # look after.
    def initialize(@config : Config, @daemon : Daemon)
      @repo = {} of String => File
    end

    # Finds all repo keys that include *query*, and returns
    # an array of repo values that correspond to them.
    private def repo_find_all(query : String)
      result = [] of {String, File}
      @repo.each do |k, f|
        result << {k, f} if k.includes?(query)
      end
      result
    end

    # Finds a repo key that matches the given *query*.
    #
    # Raises if not found, or if found multiple.
    private def repo_find_file(query : String)
      files = repo_find_all(query)

      if files.empty?
        raise InquirerError.new("#{query}: not found")
      elsif files.size > 1
        raise InquirerError.new("please stricten your relook query")
      else
        files.first
      end
    end

    # Executes the given *request*.
    #
    # Returns the appropriate `Response`.
    def execute(request : Request)
      Console.log("Execute: #{request}")

      arg = request.argument

      case request.command
      in .die?
        # Close repo files and wait to be able to send the
        # OK response.
        @repo.map { |k, f| f.close }
        spawn @daemon.stop(wait: 1.second)
      in .ping?
        # pass
      in .relook?
        filepath, file = repo_find_file(arg)
        # Scans for distinct and adds that to the repo.
        Console.error("TODO: relook #{filepath}")
      in .register?
        return Response.err unless File.exists?(arg) && File.file?(arg)
        # Opens a file for RELOOKing.
        @repo[arg] = File.open(arg)
      in .unregister?
        filepath, file = repo_find_file(arg)
        # Closes the file and removes the repo entry.
        file.close
        @repo.delete(filepath)
      in .watchables?
        return Response.ok @daemon.watchables[...arg.to_i].join("\n")
      end

      Response.ok
    rescue e : InquirerError
      return Response.err(e.message || "invalid")
    end

    # Parses a JSON *query* and formulates a `Protocol::Response`.
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

    # Starts serving the API.
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
