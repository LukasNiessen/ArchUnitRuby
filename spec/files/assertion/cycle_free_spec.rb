# frozen_string_literal: true

RSpec.describe ArchUnit::Files::Assertion do
  def raw_edge(source, target)
    ArchUnit::Edge.new(source:, target:, external: false)
  end

  def projected_edge(source, target)
    ArchUnit::ProjectedEdge.new(
      source_label: source,
      target_label: target,
      cumulated_edges: [raw_edge("#{source}.rb", "#{target}.rb")]
    )
  end

  it 'turns each cycle into immutable path data' do
    cycle = [projected_edge('api', 'domain'), projected_edge('domain', 'api')]

    violation = described_class.gather_cycle_violations([cycle]).fetch(0)

    expect(violation).to be_a(ArchUnit::Files::Assertion::CycleViolation)
    expect(violation).to be_a(ArchUnit::Violation)
    expect(violation.cycle).to eq(cycle)
    expect(violation.path).to eq(%w[api domain api])
    expect(violation.path.join(' -> ')).to eq('api -> domain -> api')
    expect(violation.cycle).to be_frozen
    expect(violation.path).to be_frozen
    expect(violation).to be_frozen
  end

  it 'returns one value per cycle and compares violations by data' do
    first = [projected_edge('a', 'b'), projected_edge('b', 'a')]
    second = [projected_edge('c', 'd'), projected_edge('d', 'c')]

    violations = described_class.gather_cycle_violations([first, second])

    expect(violations).to eq(
      [
        ArchUnit::Files::Assertion::CycleViolation.new(cycle: first),
        ArchUnit::Files::Assertion::CycleViolation.new(cycle: second)
      ]
    )
    expect(violations.first.hash).to eq(
      ArchUnit::Files::Assertion::CycleViolation.new(cycle: first).hash
    )
  end

  it 'rejects empty, discontinuous, and invalid cycle data' do
    edge = projected_edge('a', 'b')
    disconnected = projected_edge('c', 'a')

    expect { described_class.gather_cycle_violations(Object.new) }
      .to raise_error(ArgumentError, /cycles must be an Array/)
    expect { ArchUnit::Files::Assertion::CycleViolation.new(cycle: []) }
      .to raise_error(ArgumentError, /non-empty Array/)
    expect do
      ArchUnit::Files::Assertion::CycleViolation.new(cycle: [edge, disconnected])
    end.to raise_error(ArgumentError, /contiguous closed path/)
  end
end
