# frozen_string_literal: true

RSpec.describe 'metric extraction values' do
  let(:method_info) do
    ArchUnit::MetricMethodInfo.new(name: 'save', accessed_fields: %w[record id record])
  end
  let(:field_info) do
    ArchUnit::MetricFieldInfo.new(name: 'record', accessed_by: %w[save find save])
  end
  let(:class_info) do
    ArchUnit::ClassInfo.new(
      name: 'Store', file_path: 'lib\\store.rb', methods: [method_info], fields: [field_info]
    )
  end
  let(:file_info) do
    ArchUnit::MetricFileInfo.new(
      path: 'lib\\store.rb', lines_of_code: 9, statement_count: 8, import_count: 1,
      class_count: 1, function_count: 0, class_infos: [class_info]
    )
  end

  it 'normalizes, sorts, deduplicates, and freezes extracted facts' do
    expect(method_info.accessed_fields).to eq(%w[id record])
    expect(field_info.accessed_by).to eq(%w[find save])
    expect(class_info.file_path).to eq('lib/store.rb')
    expect(class_info.identifier).to eq('lib/store.rb:Store')
    expect(file_info.path).to eq('lib/store.rb')
    expect(file_info.identifier).to eq('lib/store.rb')
    expect(method_info.accessed_fields).to be_frozen
    expect(file_info.class_infos).to be_frozen
  end

  it 'derives all classes from immutable project files' do
    project = ArchUnit::MetricProjectInfo.new(project_root: 'C:\\project', files: [file_info])

    expect(project.project_root).to eq('C:/project')
    expect(project.classes).to eq([class_info])
    expect(project.classes).to be_frozen
  end

  it 'rejects invalid names, values, counts, and contained types' do
    expect { ArchUnit::MetricMethodInfo.new(name: '', accessed_fields: []) }
      .to raise_error(ArgumentError, /name/)
    expect { ArchUnit::MetricFieldInfo.new(name: 'field', accessed_by: [nil]) }
      .to raise_error(ArgumentError, /accessed_by/)
    expect do
      ArchUnit::ClassInfo.new(name: 'Store', file_path: 'store.rb', methods: [field_info])
    end.to raise_error(ArgumentError, /MethodInfo/)
    expect do
      file_info.with(lines_of_code: -1)
    end.to raise_error(ArgumentError, /lines_of_code/)
    expect do
      ArchUnit::MetricProjectInfo.new(project_root: 'project', files: [class_info])
    end.to raise_error(ArgumentError, /FileInfo/)
  end
end
