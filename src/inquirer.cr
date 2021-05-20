require "commander"
require "fancyline"
require "./inquirer/*"

module Inquirer
  VERSION = "0.1.0"

  # Inquirer CLI constructs an `Inquirer::Config` object and
  # passes it to the appropriate Inquirer facilities (those
  # which the user requested, e.g., `Inquirer::Daemon` for
  # `inquirer start`, etc.).
  class CLI
    @config = Inquirer::Config.new

    # Executes shell input *input* through the given *client*.
    #
    # Raises `InquirerError` on invalid command and on
    # connection error.
    def shell_for(client : Client, input : String)
      raise InquirerError.new("invalid syntax") unless input =~ /^(\w+)\s*([^\s]*)$/

      command = Protocol::Command.from_json($1.dump)
      request = Protocol::Request.new(command, $2)

      response = client.send(request)
      raise InquirerError.new(response.result.as? String) if response.status.err?

      case result = response.result
      in Nil then puts response.status
      in Array then puts result.join("\n")
      in String then puts result
      in Hash(String, Array(String))
        result.each do |head, children|
          puts head.colorize.bold, children.map { |child| "  * #{child}" }.join("\n")
        end
      end
    rescue JSON::ParseException
      raise InquirerError.new("invalid command")
    rescue Socket::ConnectError
      raise InquirerError.new("connection lost")
    end

    # Returns the Commander command line interface for Inquirer.
    def main
      Commander::Command.new do |cmd|
        cmd.use   = "inquirer [global options --]"
        cmd.long  = "Command line interface to the Inquirer infrastructure."

        # -p, --port
        cmd.flags.add do |flag|
          flag.name        = "port"
          flag.short       = "-p"
          flag.long        = "--port"
          flag.default     = 12879
          flag.description = "Set referent Inquirer server port."
        end

        # inquirer [global options]
        cmd.run do |options, arguments|
          Console.quit(cmd.help) if arguments.empty?

          # Build the config.
          @config.port = options.int["port"].to_i

          # Interpret the command that ended up in the arguments.
          cmd.commands.each_with_index do |command, index|
            if command.use == arguments.first?
              break Commander.run(command, arguments[1...])
            elsif index == cmd.commands.size - 1 # last?
              Console.quit(cmd.help)
            end
          end
        end

        # start [...]
        cmd.commands.add do |cmd|
          cmd.use   = "start"
          cmd.short = "Start Inquirer daemon & server."
          cmd.long  = cmd.short

          # -d, --detach
          cmd.flags.add do |flag|
            flag.name        = "detached"
            flag.short       = "-d"
            flag.long        = "--detach"
            flag.default     = false
            flag.description = "Run Inquirer in background."
          end

          # -i, --ignore
          cmd.flags.add do |flag|
            flag.name        = "ignore"
            flag.short       = "-i"
            flag.long        = "--ignore"
            flag.default     = "node_modules"
            flag.description = "Directories that are not watched (comma-separated)."
          end

          # --here
          cmd.flags.add do |flag|
            flag.name        = "here"
            flag.long        = "--here"
            flag.default     = false
            flag.description = "Set watch origin to the working directory."
          end

          cmd.run do |options, arguments|
            @config.origin = Dir.current if options.bool["here"]
            @config.ignore += options.string["ignore"].split(",")
            @config.detached = options.bool["detached"]

            if Client.from(@config).running?
              Console.exit(1, "Another Inquirer server is running on port #{@config.port}.")
            else
              Daemon.start(@config)
            end
          end
        end

        # stop [...]
        cmd.commands.add do |cmd|
          cmd.use   = "stop"
          cmd.short = "Stop Inquirer daemon & server."
          cmd.long  = cmd.short

          cmd.run do |options, arguments|
            Client.from(@config)
              .running!(exit: true)
              .command(Protocol::Command::Die)
            Console.done("Stopped.")
          end
        end

        # shell [...]
        cmd.commands.add do |cmd|
          cmd.use   = "shell"
          cmd.short = "Start an interactive shell to talk to Inquirer."
          cmd.long  = cmd.short

          cmd.run do |options, arguments|
            fancy  = Fancyline.new
            client = Client.from(@config).running!(exit: true)

            puts "Hint: type 'commands' for a list of commands."

            while input = fancy.readline(" -> ")
              begin
                puts shell_for(client, input)
              rescue e : InquirerError
                Console.error(e.message || "unknown error")
              end
            end
          end
        end
      end
    end

    # Starts Inquirer command line interface from the
    # given *argv*.
    def self.start(argv)
      Commander.run(new.main, argv)
    end
  end
end


Inquirer::CLI.start(ARGV)
