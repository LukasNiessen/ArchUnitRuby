# frozen_string_literal: true

RSpec.describe ArchUnit::Extraction::ResolvedImport do
  subject(:resolved_import) do
    described_class.new(
      module_name: '../support',
      import_kind: :require_relative,
      line_number: 7,
      resolved_path: 'C:\\project\\lib\\support.rb'
    )
  end

  it 'stores normalized immutable import data' do
    expect(resolved_import).to have_attributes(
      module_name: '../support',
      import_kind: :require_relative,
      line_number: 7,
      resolved_path: 'C:/project/lib/support.rb'
    )
    expect(resolved_import).to be_frozen
    expect(resolved_import.module_name).to be_frozen
    expect(resolved_import.resolved_path).to be_frozen
  end

  it 'permits an unresolved import' do
    import = described_class.new(
      module_name: 'unknown_library',
      import_kind: :require,
      line_number: 1
    )

    expect(import.resolved_path).to be_nil
  end

  it 'rejects invalid fields' do
    expect do
      described_class.new(module_name: '', import_kind: :require, line_number: 1)
    end.to raise_error(ArgumentError, /module_name/)

    expect do
      described_class.new(module_name: 'json', import_kind: :import, line_number: 1)
    end.to raise_error(ArgumentError, /unknown import kind/)

    expect do
      described_class.new(module_name: 'json', import_kind: :require, line_number: 0)
    end.to raise_error(ArgumentError, /line_number/)

    expect do
      described_class.new(
        module_name: 'json', import_kind: :require, line_number: 1, resolved_path: ''
      )
    end.to raise_error(ArgumentError, /resolved_path/)
  end
end
