require "colorize"

# Provides Inquirer with standardized style & utilities for
# printing stuff on the screen.
module Inquirer::Console
  extend self

  # The amount of columns in the terminal.
  COLUMNS = `tput cols`.to_i? || 80

  # Makes a plaque from the given plaque text *text* and of
  # *fore* foreground color.
  private def plaque(text : String, fore)
    "[#{text}]".colorize.bold.fore(fore)
  end

  # Displays a log plaque followed by *message*.
  #
  # Returns nothing.
  def log(message : String)
    puts "#{plaque("LOG", :blue)} #{message}"
  end

  # Displays a done plaque followed by *message*.
  #
  # Returns nothing.
  def done(message : String)
    puts "#{plaque("DONE", :green)} #{message}"
  end

  # Displays an error plaque followed by *message*.
  #
  # Returns nothing.
  def error(message : String)
    puts "#{plaque("ERROR", :red)} #{message}"
  end

  # Prints the given *message* and exits with status 0.
  def quit(with message : String)
    puts message
    exit 0
  end

  # Calls `error(message)` and exits with the given *status*.
  def exit(status : Int32, message : String)
    error(message) unless status == 0
    exit(status)
  end

  # Prints the given *message* so that the next call, it
  # changes in-place.
  #
  # Returns the carriage to the start of the line, clears
  # the line, and prints *message* with no trailing newline.
  #
  # Cuts off *message* if it doesn't fit (see `COLUMNS`).
  #
  # Returns nothing.
  def update(message : String)
    if message.size > COLUMNS
      message = "#{message[...COLUMNS - 3]}..."
    end

    print "\r#{message}#{" " * (COLUMNS - message.size)}"
  end

  # Stacks the given *message* on top of an `update`.
  def overwrite(message : String)
    update(message)
    puts
  end

  # Returns *given*, logging message *before* beforehand and
  # message *after* afterwards.
  macro comment(before, after, given)
    Console.log({{before}})
    %result = {{given}}
    Console.done({{after}})
    %result
  end
end
