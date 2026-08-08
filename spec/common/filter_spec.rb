# frozen_string_literal: true

RSpec.describe ArchUnit::Common::Filter do
  subject(:filter) do
    described_class.new(
      regexp: /service/,
      target: :filename,
      matching: :partial,
      exclusions: [exclusion]
    )
  end

  let(:exclusion) do
    described_class.new(regexp: /legacy/, target: :path, matching: :partial)
  end

  it 'carries immutable compiled matching data' do
    expect(filter).to have_attributes(
      target: :filename,
      matching: :partial,
      exclusions: [exclusion]
    )
    expect(filter).to be_frozen
    expect(filter.regexp).to be_frozen
    expect(filter.exclusions).to be_frozen
  end

  it 'protects itself from changes to constructor values' do
    regexp = /service/
    exclusions = [exclusion]
    value = described_class.new(regexp:, target: :path, exclusions:)

    exclusions.clear

    expect(value.regexp).not_to equal(regexp)
    expect(value.exclusions).to eq([exclusion])
  end

  it 'validates the regular expression, target, matching mode, and exclusions' do
    expect { described_class.new(regexp: 'glob', target: :path) }
      .to raise_error(ArgumentError, 'regexp must be a Regexp')
    expect { described_class.new(regexp: /x/, target: :folder) }
      .to raise_error(ArgumentError, 'unknown target: :folder')
    expect { described_class.new(regexp: /x/, target: :path, matching: :fuzzy) }
      .to raise_error(ArgumentError, 'unknown matching: :fuzzy')
    expect { described_class.new(regexp: /x/, target: :path, exclusions: [/y/]) }
      .to raise_error(ArgumentError, 'exclusions must contain only Filter values')
  end
end
