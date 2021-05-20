module Inquirer
  # Overall Inquirer configuration.
  class Config
    property port = 12879
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
