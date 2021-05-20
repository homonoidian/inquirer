require "json"
require "kemal"
require "./protocol"

module Inquirer
  class Server
    include Protocol

    private alias Distinct = Array(String)

    # A regex that matches the characters Ven reader ignores,
    # assuming they are at the start of the string.
    RX_VEN_IGNORES  = /^(?:[ \n\r\t]+|#(?:[ \t][^\n]*|\n+))/

    # A regex that matches Ven distinct statement, assuming
    # it is at the start of the string.
    RX_VEN_DISTINCT = /^distinct\s+(\w[\.\w]*(?<!\.))(;|;?$)/

    # Makes a Server from the given *config*.
    #
    # *daemon* is the daemon that the new server will control.
    def initialize(@config : Config, @daemon : Daemon)
      @repo = {} of Distinct => Array(String)
    end

    # Subscribes *filepath* to the given *distinct*.
    #
    # Makes the appropriate entry in the repository if *distinct*
    # is not already there.
    #
    # Returns nothing.
    private def subscribe(distinct : Distinct, filepath : String)
      index = distinct.size

      # Given *distinct* [foo, bar, baz]
      #
      # ITER  |  FRAME            |  REPO
      # #1    |  [foo]            |  foo = [*others, filepath]
      # #2    |  [foo, bar]       |  foo.bar = [*others, filepath]
      # #3    |  [foo, bar, baz]  |  foo.bar.baz = [*others, filepath]
      while index > 0
        frame = distinct[..-index]

        if filepaths = @repo[frame]?
          filepaths << filepath unless filepath.in?(filepaths)
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

    # A miniature reader that will extract a valid distinct
    # from the given *source*.
    #
    # Depends on `RX_VEN_DISTINCT` and `RX_VEN_IGNORE` being
    # up-to-date with current Ven syntax.
    #
    # Returns nil if *source* has no distinct, or if the distinct
    # it has was found invalid.
    private def distinct?(source : String) : Distinct?
      case source
      when RX_VEN_DISTINCT
        $1.split('.')
      when RX_VEN_IGNORES
        distinct?(source[$0.size..])
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

        if distinct = distinct?(contents)
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
      in .commands?
        return Response.ok({{Protocol::Command.constants.map(&.stringify.downcase)}})
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
      logging false

      before_post "/" do |env|
        env.response.content_type = "application/json"
      end

      post "/" do |env|
        respond_to(env.request.body.try &.gets_to_end).to_json
      end

      error 404 do
        render("src/views/404.ecr")
      end

      Kemal.run(@config.port, args: nil) do |config|
        Kemal.config.shutdown_message = false
      end
    end
  end
end
