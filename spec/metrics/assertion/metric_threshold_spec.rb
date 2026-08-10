# frozen_string_literal: true

RSpec.describe ArchUnit::Metrics::Assertion do
  let(:small) do
    ArchUnit::ClassInfo.new(
      name: 'Small', file_path: 'small.rb',
      methods: [ArchUnit::MetricMethodInfo.new(name: 'one')]
    )
  end
  let(:large) do
    ArchUnit::ClassInfo.new(
      name: 'Large', file_path: 'large.rb',
      methods: %w[one two three].map { |name| ArchUnit::MetricMethodInfo.new(name:) }
    )
  end
  let(:metric) { ArchUnit::CountMetrics.method_count }

  it 'implements all five numeric comparisons with exact boundaries' do
    expectations = {
      below: ['large.rb:Large'],
      above: ['small.rb:Small'],
      equal: ['large.rb:Large'],
      below_or_equal: ['large.rb:Large'],
      above_or_equal: ['small.rb:Small']
    }
    thresholds = { below: 2, above: 2, equal: 1, below_or_equal: 1, above_or_equal: 3 }

    actual = expectations.to_h do |comparison, _identifiers|
      violations = described_class.gather_metric_threshold_violations(
        [small, large], metric, comparison, thresholds.fetch(comparison)
      )
      [comparison, violations.map(&:identifier)]
    end

    expect(actual).to eq(expectations)
  end

  it 'returns immutable structured threshold evidence' do
    violation = described_class.gather_metric_threshold_violations(
      [large], metric, :below, 2
    ).fetch(0)

    expect(violation).to have_attributes(
      subject: large, identifier: 'large.rb:Large', metric_name: :method_count,
      value: 3, threshold: 2, comparison: :below
    )
    expect(violation).to be_frozen
  end

  it 'passes each built-in value and subject to should_satisfy predicates' do
    received = []
    violations = described_class.gather_metric_predicate_violations(
      [small, large], metric,
      lambda do |value, subject|
        received << [value, subject.name]
        value.odd? && subject.name == 'Small'
      end
    )

    expect(received).to eq([[1, 'Small'], [3, 'Large']])
    expect(violations).to contain_exactly(
      have_attributes(
        subject: large, identifier: 'large.rb:Large',
        metric_name: :method_count, value: 3
      )
    )
  end

  it 'validates metrics, subjects, comparisons, thresholds, and predicates' do
    expect do
      described_class.gather_metric_threshold_violations([:bad], metric, :below, 2)
    end.to raise_error(ArgumentError, /ClassInfo/)
    expect do
      described_class.gather_metric_threshold_violations([small], :bad, :below, 2)
    end.to raise_error(ArgumentError, /Metric/)
    expect do
      described_class.gather_metric_threshold_violations([small], metric, :unknown, 2)
    end.to raise_error(ArgumentError, /unknown metric comparison/)
    expect do
      described_class.gather_metric_threshold_violations([small], metric, :below, Float::NAN)
    end.to raise_error(ArgumentError, /finite real Numeric/)
    expect do
      described_class.gather_metric_predicate_violations([small], metric, nil)
    end.to raise_error(ArgumentError, /predicate/)
  end
end
