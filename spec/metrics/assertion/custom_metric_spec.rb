# frozen_string_literal: true

RSpec.describe ArchUnit::Metrics::Assertion do
  let(:class_info) do
    ArchUnit::ClassInfo.new(
      name: 'Example', file_path: 'example.rb',
      methods: [ArchUnit::MetricMethodInfo.new(name: 'perform')]
    )
  end
  let(:metric) do
    ArchUnit::Metric.new(
      name: 'method score', description: 'Methods must earn two points',
      subject_type: ArchUnit::ClassInfo,
      calculation: ->(info) { info.methods.length * 2 }
    )
  end

  it 'passes each value and its full ClassInfo to the predicate' do
    received = []
    predicate = lambda do |value, info|
      received << [value, info]
      false
    end

    violations = described_class.gather_custom_metric_violations(
      [class_info], metric, predicate
    )

    expect(received).to eq([[2, class_info]])
    expect(violations).to contain_exactly(
      an_instance_of(ArchUnit::CustomMetricViolation).and(
        have_attributes(
          class_info:, metric_name: 'method score',
          description: 'Methods must earn two points', value: 2
        )
      )
    )
  end

  it 'returns no violation when the custom predicate is truthy' do
    violations = described_class.gather_custom_metric_violations(
      [class_info], metric, ->(value, info) { value == 2 && info.name == 'Example' }
    )

    expect(violations).to be_empty
  end

  it 'validates assertion and violation inputs' do
    expect { described_class.gather_custom_metric_violations([:bad], metric, -> { true }) }
      .to raise_error(ArgumentError, /ClassInfo/)
    expect do
      described_class.gather_custom_metric_violations(
        [class_info], ArchUnit::CountMetrics.method_count, -> { true }
      )
    end.to raise_error(ArgumentError, /described custom Metric/)
    expect { described_class.gather_custom_metric_violations([class_info], metric, nil) }
      .to raise_error(ArgumentError, /predicate/)
    expect do
      ArchUnit::CustomMetricViolation.new(
        class_info: :bad, metric_name: 'score', description: 'description', value: 1
      )
    end.to raise_error(ArgumentError, /ClassInfo/)
    expect do
      ArchUnit::CustomMetricViolation.new(
        class_info:, metric_name: '', description: 'description', value: 1
      )
    end.to raise_error(ArgumentError, /metric_name/)
    expect do
      ArchUnit::CustomMetricViolation.new(
        class_info:, metric_name: 'score', description: '', value: 1
      )
    end.to raise_error(ArgumentError, /description/)
    expect do
      ArchUnit::CustomMetricViolation.new(
        class_info:, metric_name: 'score', description: 'description', value: 'one'
      )
    end.to raise_error(ArgumentError, /Numeric/)
  end
end
