# frozen_string_literal: true

RSpec.describe ArchUnit::DistanceMetrics do
  # rubocop:disable Metrics/ParameterLists -- Named fixture dimensions keep formulas readable.
  def distance_info(
    types: 1, abstract_types: 0, incoming: 0, outgoing: 0, files: 1, lines: 0
  )
    file = ArchUnit::MetricFileInfo.new(
      path: 'example.rb', lines_of_code: lines, statement_count: 0,
      import_count: 0, class_count: types, function_count: 0,
      type_count: types, abstract_type_count: abstract_types
    )
    ArchUnit::DistanceInfo.new(
      file_info: file, afferent_coupling: incoming,
      efferent_coupling: outgoing, project_file_count: files
    )
  end
  # rubocop:enable Metrics/ParameterLists

  def values_for(info)
    described_class::CALCULATIONS.to_h do |name, _calculation|
      [name, described_class.public_send(name).calculate(info)]
    end
  end

  it 'calculates abstractness, instability, coupling, and main-sequence distance' do
    info = distance_info(
      types: 2, abstract_types: 1, incoming: 2, outgoing: 2, files: 5
    )

    expect(values_for(info)).to eq(
      abstractness: 0.5, instability: 0.5, distance_from_main_sequence: 0.0,
      coupling_factor: 0.5, normalized_distance: 0.0
    )
  end

  it 'defines uncoupled and single-file projects without division errors' do
    info = distance_info

    expect(values_for(info)).to eq(
      abstractness: 0.0, instability: 0.0, distance_from_main_sequence: 1.0,
      coupling_factor: 0.0, normalized_distance: 1.0
    )
  end

  it 'uses Ruby source lines to cap the normalized distance discount at fifty percent' do
    medium = distance_info(incoming: 1, files: 2, lines: 50)
    large = distance_info(incoming: 1, files: 2, lines: 200)

    expect(described_class.normalized_distance.calculate(medium)).to eq(0.75)
    expect(described_class.normalized_distance.calculate(large)).to eq(0.5)
  end

  it 'detects both architectural zones with strict boundaries' do
    pain = distance_info(incoming: 3, files: 4)
    uselessness = distance_info(
      types: 1, abstract_types: 1, outgoing: 3, files: 4
    )
    boundary = distance_info(
      types: 10, abstract_types: 3, incoming: 3, outgoing: 1, files: 5
    )

    expect(described_class.in_zone?(pain, :pain)).to be(true)
    expect(described_class.in_zone?(uselessness, :uselessness)).to be(true)
    expect(described_class.in_zone?(boundary, :pain)).to be(false)
    expect(described_class.in_zone?(boundary, :uselessness)).to be(false)
    expect { described_class.in_zone?(pain, :unknown) }
      .to raise_error(ArgumentError, /unknown architectural zone/)
  end
end
