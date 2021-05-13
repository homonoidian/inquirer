require "json"
require "kemal"
require "ven/lib"
require "./protocol"

module Inquirer
  class Server
    include Protocol

    # Makes a Server from the given *config*.
    #
    # *daemon* is the daemon that the new server will control.
    def initialize(@config : Config, @daemon : Daemon)
      @repo = {} of Ven::Distinct => Array(String)
    end

    # Subscribes *filepath* to the given *distinct*.
    #
    # Makes the appropriate entry in the repository if *distinct*
    # is not already there.
    #
    # Returns nothing.
    private def subscribe(distinct : Ven::Distinct, filepath : String)
      index = distinct.size

      # Given *distinct* [foo, bar, baz]
      #
      # ITER  |  FRAME            |  REPO
      # #1    |  [foo]            |  foo = [*others, filepath]
      # #2    |  [foo, bar]       |  foo.bar = [*others, filepath]
      # #3    |  [foo, bar, baz]  |  foo.bar.baz = [*others, filepath]
      while index > 0
        frame = distinct[..-index]

        if (filepaths = @repo[frame]?) && !filepath.in?(filepaths)
          filepaths << filepath
        else
          @repo[frame] = [filepath]
        end

        index -= 1
      end
    end

    # Unsubscribes *filepath* from all distincts in the
    # repository.
    #
    # If *filepath* was the only subscriber of a distinct,
    # that distinct is removed as well.
    #
    # Returns nothing.
    private def purge(filepath : String)
      @repo.each do |distinct, subscribers|
        if subscribers.delete(filepath)
          Console.log("'#{filepath}' removed out of '#{distinct.join('.')}'")
        end
        if subscribers.empty? && @repo.delete(distinct)
          Console.log("Wholly purged distinct '#{distinct}'")
        end
      end
    end

    # Executes a command under *request*.
    #
    # Returns the appropriate `Response`.
    def execute(request : Request)
      Console.log("Execute: #{request}")

      arg = request.argument

      case request.command
      in .ps?
        return Response.ok @daemon.watchables[...arg.to_i]
      in .add?
        return Response.err("invalid filepath") unless
          File.readable?(arg) &&
          File.exists?(arg) &&
          File.file?(arg)

        contents = File.read(arg)
        program  = Ven::Program.new(contents, arg)

        if distinct = program.distinct
          subscribe(distinct, arg)
        else
          # If a program got here without a distinct, it's
          # useless to Inquirer.
          purge(arg)
        end
      in .die?
        spawn @daemon.stop(wait: 1.second)
      in .ping?
        return Response.ok("pong")
      in .repo?
        return Response.ok(@repo.keys.map(&.join ".").zip(@repo.values).to_h)
      in .unperson?
        purge(arg)
      in .files_for?
        if them = @repo[arg.split(".")]?
          return Response.ok(them)
        else
          return Response.err("no such distinct")
        end
      end

      Response.ok
    rescue error : InquirerError
      Response.err(error.message || "unknown error")
    end

    # Parses the given *payload* and formulates a response.
    def respond_to(payload : String?)
      begin
        unless payload.nil? || payload.empty?
          return execute Request.from_json(payload)
        end
      rescue JSON::ParseException
        # pass
      end

      Response.err("bad request")
    end

    # Starts serving the API.
    def serve
      post "/" do |env|
        env.response.content_type = "application/json"

        payload  = env.request.body.try(&.gets_to_end)
        response = respond_to(payload)

        response.to_json
      end

      Kemal.run(@config.port, args: nil) do |config|
        Kemal.config.shutdown_message = false
      end
    end
  end
end
