# frozen_string_literal: true

RSpec.describe ArchUnit::SliceProjections do
  def edge(source:, target:, external: false)
    ArchUnit::Edge.new(source:, target:, external:, import_kinds: [:require_relative])
  end

  it 'slices internal dependencies through the one (**) pattern capture' do
    projection = described_class.slice_by_pattern('lib/app/(**)/ **'.delete(' '))
    dependency = edge(source: 'lib/app/api/entry.rb', target: 'lib/app/services/orders.rb')

    expect(projection.call(dependency)).to eq(
      ArchUnit::MappedEdge.new(source_label: 'api', target_label: 'services')
    )
    expect(projection).to be_frozen
  end

  it 'filters self and intra-slice dependencies while preserving external evidence' do
    projection = described_class.slice_by_pattern('lib/app/(**)/')

    expect(projection.call(edge(source: 'lib/app/api/a.rb', target: 'lib/app/api/a.rb'))).to be_nil
    expect(projection.call(edge(source: 'lib/app/api/a.rb', target: 'lib/app/api/b.rb'))).to be_nil
    expect(
      projection.call(edge(source: 'lib/app/api/a.rb', target: 'json', external: true))
    ).to eq(ArchUnit::MappedEdge.new(source_label: 'api', target_label: 'json'))
  end

  it 'normalizes separators and returns nil when either internal endpoint is unmatched' do
    projection = described_class.slice_by_pattern('lib/app/(**)/')

    expect(projection.label_for('lib\\app\\services\\orders.rb')).to eq('services')
    expect(
      projection.call(edge(source: 'lib/app/api/a.rb', target: 'spec/support.rb'))
    ).to be_nil
  end

  it 'accepts regular expressions and uses their first capture' do
    projection = described_class.slice_by_regex(%r{\Alib/app/([^/]+)/})
    dependency = edge(source: 'lib/app/api/a.rb', target: 'lib/app/models/b.rb')

    expect(projection.call(dependency)).to have_attributes(
      source_label: 'api', target_label: 'models'
    )
    expect(described_class.slice_by_regex(%r{lib/app}).call(dependency)).to be_nil
  end

  it 'assigns suffix slices deterministically using the longest matching suffix' do
    projection = described_class.slice_by_file_suffix(
      'service' => 'generic', '_service' => 'services', '_controller' => 'controllers'
    )
    dependency = edge(source: 'order_controller.rb', target: 'order_service.rb')

    expect(projection.call(dependency)).to have_attributes(
      source_label: 'controllers', target_label: 'services'
    )
    expect(projection.label_for('helper.rb')).to be_nil
  end

  it 'provides identity projection and stable labels including isolated files' do
    projection = described_class.identity
    graph = [
      edge(source: 'lib/b.rb', target: 'lib/b.rb'),
      edge(source: 'lib/a.rb', target: 'json', external: true)
    ]

    expect(projection.call(graph.last)).to have_attributes(
      source_label: 'lib/a.rb', target_label: 'json'
    )
    expect(projection.slice_labels(graph)).to eq(['lib/a.rb', 'lib/b.rb'])
    expect(projection.slice_labels(graph)).to be_frozen
  end

  it 'validates patterns, suffix mappings, paths, edges, and labeler results' do
    expect { described_class.slice_by_pattern('lib/**') }
      .to raise_error(ArgumentError, /exactly one/)
    expect { described_class.slice_by_pattern('(**)/(**)') }
      .to raise_error(ArgumentError, /exactly one/)
    expect { described_class.slice_by_regex('not a regexp') }
      .to raise_error(ArgumentError, /Regexp/)
    expect { described_class.slice_by_file_suffix({}) }
      .to raise_error(ArgumentError, /non-empty Hash/)
    expect { described_class.slice_by_file_suffix('' => 'slice') }
      .to raise_error(ArgumentError, /suffix/)
    expect { described_class.identity.label_for('') }
      .to raise_error(ArgumentError, /path/)
    expect { described_class.identity.call(Object.new) }
      .to raise_error(ArgumentError, /Edge/)
    expect { ArchUnit::SliceProjection.new { 42 }.label_for('lib/a.rb') }
      .to raise_error(TypeError, /slice labelers/)
  end
end
