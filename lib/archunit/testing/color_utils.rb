# frozen_string_literal: true

module ArchUnit
  # Violation presentation and test-framework integration.
  module Testing
    # ANSI colour helpers that degrade to plain text outside capable terminals.
    class ColorUtils
      RESET = "\e[0m"

      class << self
        def supported?(output: $stdout, environment: ENV)
          return false unless environment['NO_COLOR'].to_s.empty?
          return false if environment['TERM'] == 'dumb'

          output.respond_to?(:tty?) && output.tty?
        end

        def red(text, enabled: supported?)
          wrap('31', text, enabled:)
        end

        def green(text, enabled: supported?)
          wrap('32', text, enabled:)
        end

        def yellow(text, enabled: supported?)
          wrap('33', text, enabled:)
        end

        def blue(text, enabled: supported?)
          wrap('34', text, enabled:)
        end

        def magenta(text, enabled: supported?)
          wrap('35', text, enabled:)
        end

        def cyan(text, enabled: supported?)
          wrap('36', text, enabled:)
        end

        def bold(text, enabled: supported?)
          wrap('1', text, enabled:)
        end

        def dim(text, enabled: supported?)
          wrap('2', text, enabled:)
        end

        private

        def wrap(code, text, enabled:)
          raise ArgumentError, 'text must be a String' unless text.is_a?(String)
          unless [true, false].include?(enabled)
            raise ArgumentError, 'enabled must be true or false'
          end
          return text unless enabled

          "\e[#{code}m#{text}#{RESET}"
        end
      end

      private_class_method :new
    end
  end
end
