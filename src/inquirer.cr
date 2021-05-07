require "commander"
require "./inquirer/*"

module Inquirer
  VERSION = "0.1.0"

  module CLI
    extend self

    ORIGIN = ENV["ORIGIN"]? || ENV["HOME"]?

    # Returns the initialized command line arguments parser.
    private def commands
      Commander::Command.new do |cmd|
        cmd.use = "inquirer"
        cmd.long = "a command-line utility to work with Ven::Inquirer"

        # inquirer start
        cmd.commands.add do |cmd|
          cmd.use = "start"
          cmd.short = "Start the Inquirer daemon."
          cmd.long = cmd.short

          # -p, --port
          cmd.flags.add do |flag|
            flag.name = "port"
            flag.short = "-p"
            flag.long = "--port"
            flag.default = 3000
            flag.description =
              "Makes Inquirer API server listen " \
              "on the port that was specified."
          end

          # -d, --detached
          cmd.flags.add do |flag|
            flag.name = "detached"
            flag.short = "-d"
            flag.long = "--detached"
            flag.default = false
            flag.description =
              "Makes the daemon run in background."
          end

          cmd.run do |options, arguments|
            origin = ORIGIN.not_nil!

            unless origin && File.exists?(origin) && File.directory?(origin)
              Console.exit(1,
                "Please provide valid $ORIGIN or $HOME so " \
                "Inquirer knows where to start working")
            end

            # Start the daemon. The daemon will check if it
            # is the only one itself.
            #
            Daemon.new(origin).start(
              port: options.int["port"].to_i32,
              detach: options.bool["detached"],
            )
          end
        end

        # inquirer stop
        cmd.commands.add do |cmd|
          cmd.use = "stop"
          cmd.short = "Stop the Inquirer daemon."
          cmd.long = cmd.short

          cmd.run do |options, arguments|
            Console.logging(
              before: "Stopping the daemon.",
              after: stopped ? "Stopped the daemon." : "The daemon is not running.",
              given: stopped = Client.running? && Client.command(Protocol::Command::Die)
            )
          end
        end

        cmd.run do |options, arguments|
          puts cmd.help
        end
      end
    end

    # Runs the Inquirer command-line utility.
    def main
      Commander.run(commands, ARGV)
    end
  end
end

Inquirer::CLI.main
