# frozen_string_literal: true

RSpec.describe ArchUnit::Metrics::Assertion do
  def distance_info(abstract_types:, incoming:, outgoing:)
    file = ArchUnit::MetricFileInfo.new(
      path: 'example.rb', lines_of_code: 10, statement_count: 1,
      import_count: 0, class_count: 1, function_count: 0,
      type_count: 1, abstract_type_count: abstract_types
    )
    ArchUnit::DistanceInfo.new(
      file_info: file, afferent_coupling: incoming,
      efferent_coupling: outgoing, project_file_count: 3
    )
  end

  it 'returns structured violations only for files in the requested zone' do
    pain = distance_info(abstract_types: 0, incoming: 2, outgoing: 0)
    balanced = distance_info(abstract_types: 0, incoming: 0, outgoing: 2)

    expect(described_class.gather_metric_zone_violations([pain, balanced], :pain))
      .to contain_exactly(
        an_instance_of(ArchUnit::MetricZoneViolation).and(
          have_attributes(
            distance_info: pain, zone: :pain, abstractness: 0.0, instability: 0.0
          )
        )
      )
  end

  it 'validates assertion inputs and violation values' do
    pain = distance_info(abstract_types: 0, incoming: 2, outgoing: 0)

    expect { described_class.gather_metric_zone_violations([:bad], :pain) }
      .to raise_error(ArgumentError, /DistanceInfo/)
    expect { described_class.gather_metric_zone_violations([pain], :unknown) }
      .to raise_error(ArgumentError, /unknown architectural zone/)
    expect { ArchUnit::MetricZoneViolation.new(distance_info: :bad, zone: :pain) }
      .to raise_error(ArgumentError, /DistanceInfo/)
    expect { ArchUnit::MetricZoneViolation.new(distance_info: pain, zone: :unknown) }
      .to raise_error(ArgumentError, /unknown architectural zone/)
  end
end
