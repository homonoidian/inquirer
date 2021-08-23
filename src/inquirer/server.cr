require "json"
require "http"
require "./protocol"

module Inquirer
  class Server
    include Protocol

    private alias Distinct = Array(String)

    # A regex that matches the characters Ven reader ignores,
    # assuming they are at the start of the matchee string.
    RX_VEN_IGNORES = /^(?:[ \n\r\t]+|#(?:[ \t][^\n]*|\n+))/

    # A regex that matches Ven distinct statement, assuming
    # it is at the start of the matchee string.
    RX_VEN_DISTINCT = /^distinct\s+(\w[\.\w]*(?<!\.))(;|;?$)/

    # Makes a Server from the given *config*.
    #
    # *daemon* is the daemon that the new server will have
    # control over.
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
    # Will log the command if *log* unless *log* is false.
    #
    # Returns the appropriate `Response`.
    def execute(request : Request, log = true)
      Console.log("Execute: #{request}") if log

      arg = request.argument

      case request.command
      in .ps?
        return Response.ok @daemon.watchables[...arg.to_i]
      in .relook?
        unless File.file?(arg) && File.readable?(arg)
          return Response.err("invalid filepath")
        end

        contents = File.read(arg)

        if distinct = distinct?(contents)
          # Found a valid distinct statement in the file,
          # subscribe the file to the distinct in the repo.
          subscribe(distinct, arg)
        else
          # Did not find a valid distinct statement. If the
          # file was in the repository, remove all mentions
          # of it.
          purge(arg)
        end
      in .die?
        if log
          Console.log("Stopping the daemon.")
        end

        @daemon.stop

        spawn do
          sleep 1.second
          # We gave the server some time to send the OK response;
          # now we can quit. Is there a better approach, though?
          exit 0
        end
      in .ping?
        return Response.ok("pong")
      in .repo?
        return Response.ok(@repo.keys.map(&.join ".").zip(@repo.values).to_h)
      in .purge?
        purge(arg)
      in .commands?
        return Response.ok({{Protocol::Command.constants.map(&.stringify.downcase)}})
      in .files_for?
        if them = @repo[arg.split(".")]?
          return Response.ok(them)
        else
          return Response.err("no such distinct")
        end
      in .source_for?
        # Reading files like that is damn dangerous, as anyone
        # with access to port 12879, or whatever other Inquirer
        # port, can send `SourceFor /etc/passwd`!
        #
        # As a security precaution, we (a) set the argument path's
        # base to the origin directory path, and (b) expand the
        # argument path to check whether it still talks about
        # the origin directory.
        clean_base = Path[@config.origin].expand(base: "/")
        clean_arg = Path[arg].expand(base: clean_base)

        unless clean_arg.parent == clean_base
          return Response.err("filepath left origin")
        end

        # Make sure that the resulting file extension is '.ven',
        # so we do not extrinsic files.
        unless clean_arg.extension == ".ven"
          return Response.err("can reference only files with .ven extension")
        end

        unless File.file?(clean_arg) && File.readable?(clean_arg)
          return Response.err("no such target")
        end

        # And only when we are sure the filename is clean,
        # and exists, we read the file and send over its
        # source code.
        return Response.ok File.read(clean_arg)
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
      server = HTTP::Server.new do |context|
        req, res = context.request, context.response
        # 1) Set response type.
        res.content_type = "application/json"
        res.headers["Connection"] = "keep-alive"
        # 2) Validate the request.
        res.status = HTTP::Status::IM_A_TEAPOT
        next unless req.method == "POST" && req.resource == "/"
        # 3) Read the body.
        body = req.body.try(&.gets_to_end)
        # 4) Respond to body.
        res.status = HTTP::Status::OK
        res.print respond_to(body).to_json
      end

      address = server.bind_tcp("0.0.0.0", @config.port)

      at_exit do
        Console.comment(
          before: "Shutting down the server...",
          after: "Server shut down.",
          given: server.close
        )
      end

      Console.done("API listening on #{address}")
      server.listen
    end
  end
end
