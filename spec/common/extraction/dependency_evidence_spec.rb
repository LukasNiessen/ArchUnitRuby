# frozen_string_literal: true

RSpec.describe ArchUnit::DependencyEvidence do
  def evidence(**attributes)
    described_class.new(
      source: 'app/api.rb', kind: :constant_reference, name: 'Store', line_number: 3,
      **attributes
    )
  end

  it 'owns immutable source strings and validates source and target spans' do
    name = +'Store'
    value = evidence(source: 'app\\api.rb', name:, end_line: 5, target_line_number: 2)
    name.replace('Other')

    expect(value).to have_attributes(source: 'app/api.rb', name: 'Store', end_line: 5)
    expect(value.name).to be_frozen
    expect(value.source).to be_frozen
    expect(value).to be_frozen
  end

  it 'rejects invalid evidence identities and line spans' do
    expect { evidence(kind: :dynamic) }.to raise_error(ArgumentError, /valid dependency kind/)
    expect { evidence(source: nil) }.to raise_error(ArgumentError, /requires a source/)
    expect { evidence(name: nil) }.to raise_error(ArgumentError, /requires a source/)
    [0, nil, '3'].each do |line|
      expect { evidence(line_number: line) }.to raise_error(ArgumentError, /source line numbers/)
    end
    expect { evidence(end_line: 2) }.to raise_error(ArgumentError, /source line numbers/)
    expect { evidence(target_line_number: 0) }.to raise_error(ArgumentError, /source line numbers/)
  end

  it 'requires typed evidence on raw and report edges' do
    expect do
      ArchUnit::Edge.new(source: 'a.rb', target: 'b.rb', external: false, evidence: ['untyped'])
    end.to raise_error(ArgumentError, /DependencyEvidence/)
    expect do
      ArchUnit::GraphReportEdge.new(
        source: 'a.rb', target: 'b.rb', external: false, count: 1, evidence: ['untyped']
      )
    end.to raise_error(ArgumentError, /DependencyEvidence/)
  end
end
