# frozen_string_literal: true

require_relative 'technical_error'
require_relative '../common/extraction/parse_diagnostic'

module ArchUnit
  # An included source could not be analyzed; never an ordinary architecture violation.
  class SourceParseError < TechnicalError
    # @return [Array<Common::Extraction::ParseDiagnostic>] immutable source diagnostics
    attr_reader :diagnostics

    # @return [Prism::ParseResult] the complete result, or a technical failure
    def self.validate!(result, path:)
      return result if result.success?

      diagnostics = result.errors.map do |error|
        Common::Extraction::ParseDiagnostic.new(
          path: path.to_s, line: error.location.start_line,
          column: error.location.start_column + 1, message: error.message
        )
      end
      raise SourceParseError, diagnostics
    end

    def initialize(diagnostics)
      unless diagnostics.is_a?(Array) && !diagnostics.empty? &&
             diagnostics.all?(Common::Extraction::ParseDiagnostic)
        raise ArgumentError, 'source parse error requires non-empty parse diagnostics'
      end

      @diagnostics = diagnostics.dup.freeze
      details = @diagnostics.map do |item|
        "#{item.path}:#{item.line}:#{item.column}: #{item.message}"
      end
      super("Cannot analyze malformed Ruby source:\n#{details.join("\n")}")
    end
  end
end
