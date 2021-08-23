module Inquirer
  # Overall Inquirer configuration.
  class Config
    # The port number this Inquirer instance is running on.
    property port : Int32 = 12879
    # An array of directories to ignore.
    property ignore : Array(String) = %w[node_modules]
    # The origin directory. It is somewhat similar to the root ('/')
    # directory in Linux & Co., in that you can't go higher.
    property origin : String = ENV["ORIGIN"]? || ENV["HOME"]? || "."
    # Whether this Inquirer instance is running detached,
    # i.e., as a daemon.
    property detached = false

    def to_s(io)
      {% for var in @type.instance_vars %}
        io << {{var.stringify}} << " = " << {{var}} << "\n"
      {% end %}
    end
  end
end
