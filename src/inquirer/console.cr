require "colorize"

# Provides Inquirer with various printing utilities.
module Inquirer::Console
  extend self

  # The amount of columns in terminal.
  COLUMNS = ENV["COLUMNS"]?.try(&.to_i) || 80

  # Done plaque background color.
  DONE_FORE = Colorize::ColorRGB.new(165, 214, 167)
  # Error plaque background color.
  ERROR_FORE = Colorize::ColorRGB.new(239, 154, 154)
  # Progress plaque background color.
  PROGRESS_FORE = Colorize::ColorRGB.new(144, 202, 249)

  # Makes a plaque from the given plaque text *text* and
  # *fore* and *back* colors.
  private def plaque(text : String, fore : Colorize::ColorRGB)
    "[#{text}]".colorize.bold.fore(fore)
  end

  # Displays a done plaque followed by *message*.
  def done(message : String)
    puts "#{plaque("DONE", DONE_FORE)} #{message}"
  end

  # Displays an error plaque followed by *message*.
  def error(message : String)
    puts "#{plaque("ERROR", ERROR_FORE)} #{message}"
  end

  # Displays a progress plaque followed by *message*.
  def progress(message : String)
    puts "#{plaque("PROGRESS", PROGRESS_FORE)} #{message}"
  end

  # Exits with status *status*.
  #
  # If *status* is not zero, an `error` with the given
  # *message* is printed.
  def exit(status : Int32, message : String)
    error(message) unless status == 0

    exit(status)
  end

  # Displays *message*, assuming it will change the
  # next moment.
  #
  # Works like Crystal's `print`, but returns the carriage
  # to the start of the line and clears that line before
  # printing.
  #
  # Cuts off the *message* if it is too long to display on
  # one line.
  #
  # Returns nothing.
  def update(message : String)
    if message.size > COLUMNS
      message = "#{message[...COLUMNS - 3]}..."
    end

    print "\r#{message}#{" " * (COLUMNS - message.size)}"
  end

  # Logs `progress` with message *before*, executes *given*
  # and logs `done` with message *after*.
  #
  # Returns whatever *given* returned.
  macro logging(before, after, given)
    Console.progress({{before}})
    %result = {{given}}
    Console.done({{after}})
    %result
  end
end
