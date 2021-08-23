require "inotify"
require "./console"
require "../contrib/daemonize"

module Inquirer
  # The Inquirer daemon listens for certain changes in watchables
  # (watchable directories), which are recursively looked up from
  # the root (origin) directory, and reports those changes to the
  # Inquirer server.
  class Daemon
    include Protocol

    # Maximum amount of watches that this system allows.
    MAX_WATCHES = File.read("/proc/sys/fs/inotify/max_user_watches").to_i

    # Returns the directories that this daemon watches.
    getter watchables : Array(String)

    @watcher = Inotify::Watcher.new

    # Makes an Inquirer daemon from the given *config*.
    def initialize(@config : Config)
      @origin = @config.origin.as String
      @ignore = @config.ignore.as Array(String)

      Console.comment(
        before: "Searching for watchables in #{@origin}...",
        after: "Found #{@watchables.size} watchables.",
        given: @watchables = watchables!
      )

      allowed = MAX_WATCHES > @watchables.size

      unless allowed
        Console.exit(1,
          "Your system does not allow #{@watchables.size} " \
          "watches; please choose a simpler origin directory.",
        )
      end
    end

    # Fills up this daemon's list of watchable (see `watchable?`)
    # directories.
    #
    # Depth (amount of nesting) is unlimited. Searches through
    # everything under the origin directory, so may take a
    # long time.
    def watchables!
      result = Dir["#{@origin}/**/"].reject do |path|
        Console.update("⮡ #{path}")
        # Reject those that are not watchable:
        !watchable?(path)
      end

      puts # Output the final newline.

      result
    end

    # Returns whether the directory at *path* is watchable.
    #
    # Directories that are not watchable:
    # - Those whose name is prefixed with an underscore;
    # - Those that are ignored through the config;
    # - Those that are symlinks;
    # - Those that are hidden.
    def watchable?(path : String) : Bool
      !path.split("/", remove_empty: true).any? { |part|
        part.starts_with?('_') ||
          part.starts_with?('.') ||
          part.in?(@ignore)
      }
    end

    # Registers Ven files that are already in watchables.
    #
    # Any file that ends with '.ven' and is not prefixed with
    # an underscore is considered a Ven file.
    #
    # Requires watchables to be looked up beforehand.
    #
    # May take a long time as well.
    def register_existing_files(server : Inquirer::Server)
      @watchables.each do |watchable|
        Dir["#{watchable}/[^_]*.ven"].each do |file|
          Console.overwrite("Relook: #{file}")

          server.execute(Request.new(Command::Relook, file), log: false)
        end
        Console.update("In: #{watchable}")
      end

      puts # Output the final newline.
    end

    # Handles a change in a watchable.
    #
    # - If a Ven file ('[^_]*.ven') was created, modified,
    # deleted or moved (inotify MODIFY, CREATE, DELETE and
    # MOVE, correspondingly), the appropriate command about
    # that change is sent to the server.
    # - If a watchable directory was created, a watcher is set
    # on this directory.
    # - If a watchable directory was removed, its watcher is
    # (automatically) suspended.
    #
    # Returns nothing.
    def handle(server : Inquirer::Server, event : Inotify::Event)
      return unless (filename = event.name) && (responsible = event.path)

      event_path = Path[responsible, filename].to_s

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
        when .modify?, .moved_to?
          server.execute Request.new(Command::Relook, event_path)
        when .delete?, .moved_from?
          server.execute Request.new(Command::Purge, event_path)
        else
          Console.error("Unhandled event: #{event}")
        end
      end
    end

    # Starts this daemon. Detaches (daemonizes) if the config
    # says to.
    #
    # Does not check whether another daemon is running on
    # the same port.
    #
    # Returns nothing.
    def start
      server = Server.new(@config, self)

      register_existing_files(server)
      # Register the watchers for each watchable.
      @watchables.each { |watchable| @watcher.watch(watchable) }
      # Set the inotify handler.
      @watcher.on_event { |event| handle(server, event) }

      Console.done("Listening for changes in '#{@origin}'.")

      Daemonize.daemonize if @config.detached

      # Start the API server. From now on, the server is
      # in control.
      server.serve
    end

    # Gracefully stops this daemon.
    def stop
      @watcher.close
    end

    # Initializes a daemon and starts it.
    #
    # See `initialize`, `start`.
    def self.start(config : Config)
      new(config).start
    end
  end
end
