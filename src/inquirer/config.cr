module Inquirer
  # Overall Inquirer configuration that gets passed to all
  # interested parts of Inquirer.
  class Config
    property port = 3000
    property ignore = %w[node_modules]
    property origin = ENV["ORIGIN"]? || ENV["HOME"]? || "."
    property detached = false

    def to_s(io)
      {% for var in @type.instance_vars %}
        io << {{var.stringify}} << " = " << {{var}} << "\n"
      {% end %}
    end
  end
end
