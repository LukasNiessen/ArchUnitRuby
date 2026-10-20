# frozen_string_literal: true

require_relative '../error/user_error'
require_relative '../error/technical_error'

module ArchUnit
  module Extraction
    # Reads bounded, repository-owned exclusions without evaluating project code.
    # Only the project-root .archignore is read. Symlinks and negation are rejected.
    module ArchIgnore
      MAX_BYTES = 1024 * 1024

      module_function

      # @param root [Pathname] canonical project root
      # @return [Array<String>] exclusion patterns using the source enumerator's glob syntax
      def patterns(root)
        path = root.join('.archignore')
        stat = configuration_stat(path)
        return [] unless stat

        validate_configuration(stat)
        parse(read_configuration(path))
      rescue Errno::ELOOP
        raise UserError, '.archignore must not be a symlink'
      rescue SystemCallError, IOError => e
        raise TechnicalError, "could not read .archignore: #{e.message}"
      end

      def configuration_stat(path)
        path.lstat
      rescue Errno::ENOENT
        nil
      end
      private_class_method :configuration_stat

      def validate_configuration(stat)
        return if stat.file? && !stat.symlink?

        raise UserError, '.archignore must be a regular file, not a symlink or directory'
      end
      private_class_method :validate_configuration

      def read_configuration(path)
        flags = File::RDONLY
        # Windows defines NONBLOCK as 1, which is also WRONLY: do not use it there.
        flags |= File::NOFOLLOW | File::NONBLOCK if File.const_defined?(:NOFOLLOW)
        File.open(path, flags) do |file|
          raise UserError, '.archignore must be a regular file' unless file.stat.file?

          bounded_contents(file)
        end
      end
      private_class_method :read_configuration

      def bounded_contents(file)
        contents = file.binmode.read(MAX_BYTES + 1) || String.new
        raise UserError, '.archignore exceeds the 1 MiB size limit' if contents.bytesize > MAX_BYTES

        contents
      end
      private_class_method :bounded_contents

      def parse(contents)
        contents.force_encoding(Encoding::UTF_8).scrub.delete_prefix("\uFEFF")
                .each_line.filter_map do |line|
          pattern = line.strip.tr('\\', '/')
          next if pattern.empty? || pattern.start_with?('#')

          if pattern.start_with?('!') || pattern.include?("\0")
            raise UserError, '.archignore does not support negation (!) or NUL characters'
          end

          directory_pattern(pattern)
        end
      end
      private_class_method :parse

      def directory_pattern(pattern)
        return pattern unless pattern.end_with?('/')

        pattern = pattern.delete_suffix('/')
        raise UserError, '.archignore cannot exclude the project root with /' if pattern.empty?

        prefix = pattern.include?('/') ? '' : '**/'
        "#{prefix}#{pattern}/**"
      end
      private_class_method :directory_pattern
    end
  end
end
