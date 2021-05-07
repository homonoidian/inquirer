require "inotify"
require "./console"
require "../contrib/daemonize"

module Inquirer
  class Daemon
    # Which directories should not be searched in.
    IGNORES = %(node_modules)

    # Maximum amount of watches that this system allows.
    MAX_WATCHES = File.read("/proc/sys/fs/inotify/max_user_watches").to_i

    # Returns the watchable directories found by this daemon.
    getter watchables : Array(String)

    @watcher = Inotify::Watcher.new

    # Makes a Daemon and prepares it for starting.
    #
    # Daemon will listen for Ven-specific changes in *origin*,
    # as well as all of its subdirectories, subdirectories of
    # that etc. Depth (amount of nesting) is arbitrary (but
    # see `watchables`).
    def initialize(@root : String)
      Console.logging(
        before: "Searching for watchables in #{@root}...",
        after:  "Found #{@watchables.size} watchables.",
        given:  @watchables = watchables,
      )

      watchable = MAX_WATCHES > @watchables.size

      unless watchable
        Console.exit(1,
          "Your system does not allow #{@watchables.size} watches; " \
          "please restrict watchables by setting $ORIGIN.")
      end
    end

    # Returns a list of watchable directories.
    #
    # Directories that are not watchable:
    # - Those whose name is prefixed with an underscore;
    # - Those that are symlinks;
    # - Those that are hidden;
    # - Those that are in `IGNORES`.
    #
    # Depth (amount of nesting) is arbitrary. Searches through
    # everything, so may take a long time.
    def watchables
      result = Dir["#{@root}/**/"].reject do |path|
        Console.update("⮡ #{path}")

        path.split("/", remove_empty: true).any? { |part|
          part.starts_with?('_') ||
          part.starts_with?('.') ||
          part.in?(IGNORES)
        }
      end

      # Output the final newline (`Display.update` doesn't
      # produce one):
      #
      puts

      result
    end

    # Handles a change in any of the watchables.
    #
    # Returns nothing.
    def handle(event : Inotify::Event)
      puts event
    end

    # Starts this daemon.
    #
    # Detaches (daemonizes) if *detach* is true.
    #
    # *port* is the port on which the API server (`Inquirer::Server`
    # will run).
    #
    # All control except intercepting the changes in watchables
    # is transferred to Kemal.
    #
    # Returns nothing.
    def start(port = 3000, detach = false)
      # Check if another daemon is running on this port.
      #
      if Client.running?
        Console.exit(1,
          "Another instance of Inquirer is running at port #{port}. " \
          "Consider stopping it or choose a different port.")
      end

      # Register the watchers for each watchable.
      #
      @watchables.each do |watchable|
        @watcher.watch(watchable)
      end

      # Set the inotify handler.
      #
      @watcher.on_event do |event|
        handle(event)
      end

      Console.done("Listening for changes in '#{@root}'.")
      Console.done("API running on port #{port}.")

      Daemonize.daemonize if detach

      # Start the API server. From now on, Kemal is in control.
      # Kemal will occupy the fiber and keep inotify running.
      #
      Server.new(self).listen(port)
    end

    # Gracefully (in theory) stops this daemon.
    #
    # Should unregister all inotify watchers and stop the
    # server.
    #
    # Curiously, this suicides the `Server`, so it won't say
    # 'farewell!'. It can delay the death using *wait*, though.
    def stop(wait : Time::Span = nil)
      Console.progress("I will die.")
      sleep wait unless wait.nil?

      Console.progress("Closing watchers.")
      @watcher.close

      Console.done("Exiting.")
      exit 0
    end
  end
end
