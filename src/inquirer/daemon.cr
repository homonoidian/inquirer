require "inotify"
require "./console"
require "../contrib/daemonize"

module Inquirer
  # The Inquirer daemon listens for changes in watchables
  # (watchable directories), which are recursively looked
  # up from the root (origin) directory, and reports those
  # changes to the Inquirer server.
  class Daemon
    include Protocol

    # Maximum amount of watches that this system allows.
    MAX_WATCHES = File.read("/proc/sys/fs/inotify/max_user_watches").to_i

    # Returns the watchable directories found by this daemon.
    getter watchables : Array(String)

    @watcher = Inotify::Watcher.new

    # Makes an Inquirer daemon from the given *config*.
    def initialize(@config : Config)
      @origin = @config.origin.as String
      @ignore = @config.ignore.as Array(String)

      Console.comment(
        before: "Searching for watchables in #{@origin}...",
        after:  "Found #{@watchables.size} watchables.",
        given:  @watchables = watchables!,
      )

      watchable = MAX_WATCHES > @watchables.size

      unless watchable
        Console.exit(1,
          "Your system does not allow #{@watchables.size} " \
          "watches; please choose a simpler origin directory.")
      end
    end

    # Makes a list of watchable (see `watchable?`) directories.
    #
    # Depth (amount of nesting) is arbitrary. Searches through
    # everything under the origin directory, therefore may take
    # a long time.
    def watchables!
      result = Dir["#{@origin}/**/"].reject do |path|
        Console.update("⮡ #{path}")
        # Reject those that are not watchable:
        !watchable?(path)
      end

      # Output the final newline (`Display.update` doesn't
      # produce one):
      puts

      result
    end

    # Returns whether the directory at *path* is watchable.
    #
    # Directories that are not watchable:
    # - Those whose name is prefixed with an underscore;
    # - Those that are symlinks;
    # - Those that are hidden;
    # - Those that are ignored.
    def watchable?(path : String) : Bool
      !path.split("/", remove_empty: true).any? { |part|
        part.starts_with?('_') ||
        part.starts_with?('.') ||
        part.in?(@ignore)
      }
    end

    # Handles a change in a watchable.
    #
    # - If a Ven file ('[^_]*.ven') was created, modified,
    # deleted or moved (inotify MODIFY, CREATE, DELETE, MOVE),
    # the appropriate command about that change is sent to
    # the server.
    # - If a watchable directory was created, a watcher is
    # set on this directory.
    # - If a watchable directory was removed, its watcher is
    # (automatically) suspended.
    #
    # Returns nothing.
    def handle(server : Inquirer::Server, event : Inotify::Event)
      return unless (filename = event.name) && (responsible = event.path)

      event_path = "#{responsible}/#{filename}"

      if event.directory? && watchable?(event_path)
        # Directory events are handled by the daemon.
        case event.type
        when .create?
          Console.log("Register watchable sub-directory: #{event_path}")
          @watcher.watch(event_path)
        when .delete?
          Console.log("Watchable sub-directory deleted: #{event_path}")
        end
      elsif File.match?("[^_]*.ven", filename)
        # Ven file events are handled by the server.
        Console.log("Ven file change detected: #{event_path}")
        case event.type
        when .create?
          server.execute Request.new(Command::Register, event_path)
        when .modify?, .moved_to?
          server.execute Request.new(Command::Relook, event_path)
        when .delete?, .moved_from?
          server.execute Request.new(Command::Unregister, event_path)
        else
          Console.error("Unhandled event: #{event}")
        end
      end
    end

    # Starts this daemon. Detaches (daemonizes) if `Config.detached`.
    # Returns nothing. Does not check whether another daemon is
    # running on the same port.
    def start
      server = Server.new(@config, self)

      # Register the watchers for each watchable.
      @watchables.each { |watchable| @watcher.watch(watchable) }
      # Set the inotify handler.
      @watcher.on_event { |event| handle(server, event) }

      Console.done("Listening for changes in '#{@origin}'.")
      Console.done("API running on port #{@config.port}.")

      Daemonize.daemonize if @config.detached

      # Start the API server. From now on, Kemal is in control.
      # Kemal will occupy the fiber and keep inotify running.
      server.serve
    end

    # Gracefully (in theory) stops this daemon.
    #
    # Should unregister all inotify watchers and stop the
    # server.
    #
    # Curiously, this suicides the server, so it won't respond
    # with 'goodbye!'. It can wait for some *time* before dying,
    # though.
    def stop(wait time : Time::Span = nil)
      Console.log("I will die.")
      sleep time unless time.nil?

      Console.log("Closing watchers.")
      @watcher.close

      Console.done("Exiting.")
      exit 0
    end

    # A shorthand for `initialize` followed by `start`.
    def self.start(config : Config)
      new(config).start
    end
  end
end
