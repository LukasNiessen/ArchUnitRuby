# frozen_string_literal: true

module ArchUnit
  module Extraction
    # Mutable per-run timing and counter collector for cold/warm extraction benchmarks.
    class ExtractionProfile
      STAGES = %i[
        total
        project_discovery
        source_enumeration
        load_path_discovery
        file_read
        prism_parse
        import_extraction
        target_resolution
        target_index
        edge_classification
        edge_merge
      ].freeze
      COUNTERS = %i[
        source_files
        imports
        resolution_cache_hits
        resolution_cache_misses
        raw_edges
        merged_edges
      ].freeze

      attr_reader :stage_seconds, :counters

      def self.measure(profile, stage, &operation)
        return operation.call unless profile

        profile.measure(stage, &operation)
      end

      def self.validate(value)
        return if value.nil? || value.is_a?(self)

        raise ArgumentError, 'profile must be an ExtractionProfile value or nil'
      end

      def initialize(clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
        raise ArgumentError, 'clock must respond to call' unless clock.respond_to?(:call)

        @clock = clock
        @stage_seconds = STAGES.to_h { |stage| [stage, 0.0] }
        @counters = COUNTERS.to_h { |counter| [counter, 0] }
        @cache_hit = false
      end

      def measure(stage)
        validate_stage(stage)
        started_at = @clock.call
        yield
      ensure
        @stage_seconds[stage] += @clock.call - started_at if started_at
      end

      def increment(counter, amount = 1)
        validate_counter(counter)
        unless amount.is_a?(Integer) && !amount.negative?
          raise ArgumentError, 'counter amount must be a non-negative Integer'
        end

        @counters[counter] += amount
      end

      def record_cache_hit
        @cache_hit = true
      end

      def cache_hit?
        @cache_hit
      end

      def to_h
        {
          cache_hit: cache_hit?,
          stage_seconds: stage_seconds.transform_values { |value| value.round(6) },
          counters: counters.dup
        }
      end

      private

      def validate_stage(stage)
        return if STAGES.include?(stage)

        raise ArgumentError, "unknown extraction stage: #{stage.inspect}"
      end

      def validate_counter(counter)
        return if COUNTERS.include?(counter)

        raise ArgumentError, "unknown extraction counter: #{counter.inspect}"
      end
    end
  end
end
