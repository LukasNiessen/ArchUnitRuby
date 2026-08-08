# frozen_string_literal: true

module ArchUnit
  module Common
    # Compiles user-facing glob strings into the regular expressions used by the kernel.
    module Pattern
      module_function

      def compile(pattern)
        case pattern
        when String
          compile_glob(pattern.tr('\\', '/'))
        when Regexp
          pattern.dup.freeze
        else
          raise ArgumentError, 'pattern must be a String glob or Regexp'
        end
      end

      def valid?(pattern)
        pattern.is_a?(String) || pattern.is_a?(Regexp)
      end

      def compile_glob(glob)
        characters = glob.chars
        source = +'\\A'
        index = 0

        while index < characters.length
          fragment, index = compile_fragment(characters, index)
          source << fragment
        end

        Regexp.new("#{source}\\z").freeze
      end
      private_class_method :compile_glob

      def compile_fragment(characters, index)
        case characters[index]
        when '*'
          compile_star(characters, index)
        when '?'
          ['[^/]', index + 1]
        when '['
          compile_character_class(characters, index)
        else
          [Regexp.escape(characters[index]), index + 1]
        end
      end
      private_class_method :compile_fragment

      def compile_star(characters, index)
        return ['[^/]*', index + 1] unless characters[index + 1] == '*'

        index += 2
        index += 1 while characters[index] == '*'
        return ['.*', index] unless characters[index] == '/'

        ['(?:.*/)?', index + 1]
      end
      private_class_method :compile_star

      def compile_character_class(characters, index)
        closing_index = character_class_closing_index(characters, index)
        return ['\\[', index + 1] if closing_index.nil? || closing_index == index + 1

        content = characters[(index + 1)...closing_index]
        return ['\\[', index + 1] if content == ['!']

        [character_class_fragment(content), closing_index + 1]
      end
      private_class_method :compile_character_class

      def character_class_closing_index(characters, index)
        closing_offset = characters[(index + 1)..].index(']')
        closing_offset && (index + closing_offset + 1)
      end
      private_class_method :character_class_closing_index

      def character_class_fragment(content)
        content = content.dup
        negated = content.first == '!'
        content.shift if negated

        escaped_content = content.map { |character| escape_class_character(character) }.join
        prefix = negated ? '^' : ''
        "(?=[^/])[#{prefix}#{escaped_content}]"
      end
      private_class_method :character_class_fragment

      def escape_class_character(character)
        return "\\#{character}" if ['\\', '[', ']', '&', '^'].include?(character)

        character
      end
      private_class_method :escape_class_character
    end
  end
end
