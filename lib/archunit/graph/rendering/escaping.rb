# frozen_string_literal: true

require 'cgi/escape'

module ArchUnit
  module GraphReporting
    module Rendering
      # Format-specific escaping kept out of the renderers' graph logic.
      module Escaping
        module_function

        def quoted(value)
          escaped = value.gsub('\\', '\\\\').gsub('"', '\\"').gsub("\n", '\\n')
          "\"#{escaped}\""
        end

        def mermaid_label(value)
          CGI.escapeHTML(value).gsub("\n", '<br/>')
        end

        def html(value)
          CGI.escapeHTML(value.to_s)
        end

        def single_line(value)
          value.gsub(/[\r\n]+/, ' ')
        end
      end
    end
  end
end
