# frozen_string_literal: true

RSpec.describe ArchUnit::Common::Projection, 'built-in edge projections' do
  def edge(source, target, external: false)
    ArchUnit::Edge.new(source:, target:, external:)
  end

  describe '.per_edge' do
    subject(:mapper) { described_class.per_edge }

    it 'maps internal and external dependencies with their original labels' do
      internal = mapper.call(edge('source.rb', 'target.rb'))
      external = mapper.call(edge('source.rb', 'json', external: true))

      expect(internal).to eq(
        ArchUnit::MappedEdge.new(source_label: 'source.rb', target_label: 'target.rb')
      )
      expect(external).to eq(
        ArchUnit::MappedEdge.new(source_label: 'source.rb', target_label: 'json')
      )
    end

    it 'filters source-file self-edges' do
      expect(mapper.call(edge('source.rb', 'source.rb'))).to be_nil
    end
  end

  describe '.per_internal_edge' do
    subject(:mapper) { described_class.per_internal_edge }

    it 'maps only non-self internal dependencies' do
      expect(mapper.call(edge('source.rb', 'target.rb'))).to have_attributes(
        source_label: 'source.rb', target_label: 'target.rb'
      )
      expect(mapper.call(edge('source.rb', 'json', external: true))).to be_nil
      expect(mapper.call(edge('source.rb', 'source.rb'))).to be_nil
    end
  end

  describe '.per_external_edge' do
    subject(:mapper) { described_class.per_external_edge }

    it 'maps only non-self external dependencies' do
      expect(mapper.call(edge('source.rb', 'json', external: true))).to have_attributes(
        source_label: 'source.rb', target_label: 'json'
      )
      expect(mapper.call(edge('source.rb', 'target.rb'))).to be_nil
      expect(mapper.call(edge('source.rb', 'source.rb', external: true))).to be_nil
    end
  end

  describe '.identity' do
    subject(:mapper) { described_class.identity }

    it 'maps every edge, including self-edges' do
      raw_edge = edge('source.rb', 'source.rb')

      expect(mapper.call(raw_edge)).to eq(
        ArchUnit::MappedEdge.new(source_label: 'source.rb', target_label: 'source.rb')
      )
    end
  end

  it 'integrates with project_edges without custom mapping code' do
    internal = edge('source.rb', 'target.rb')
    external = edge('source.rb', 'json', external: true)
    self_edge = edge('source.rb', 'source.rb')

    projected = described_class.project_edges(
      [self_edge, internal, external], described_class.per_internal_edge
    )

    expect(projected).to contain_exactly(
      ArchUnit::ProjectedEdge.new(
        source_label: 'source.rb', target_label: 'target.rb', cumulated_edges: [internal]
      )
    )
  end
end
