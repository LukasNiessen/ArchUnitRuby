# frozen_string_literal: true

RSpec.describe ArchUnit::CountMetrics do
  let(:class_info) do
    ArchUnit::ClassInfo.new(
      name: 'Store', file_path: 'lib/store.rb',
      methods: [ArchUnit::MetricMethodInfo.new(name: 'save')],
      fields: [ArchUnit::MetricFieldInfo.new(name: 'record')]
    )
  end
  let(:file_info) do
    ArchUnit::MetricFileInfo.new(
      path: 'lib/store.rb', lines_of_code: 10, statement_count: 8, import_count: 2,
      class_count: 1, function_count: 3, class_infos: [class_info]
    )
  end

  it 'calculates the two Ruby class counts' do
    expect(described_class.method_count.calculate(class_info)).to eq(1)
    expect(described_class.field_count.calculate(class_info)).to eq(1)
  end

  it 'calculates all five Ruby file counts' do
    expect(
      %i[lines_of_code statements imports classes functions].to_h do |name|
        [name, described_class.public_send(name).calculate(file_info)]
      end
    ).to eq(lines_of_code: 10, statements: 8, imports: 2, classes: 1, functions: 3)
  end

  it 'publishes immutable, typed, numeric metric definitions' do
    metric = ArchUnit::Metric.new(
      name: :example, subject_type: ArchUnit::ClassInfo, calculation: ->(_subject) { 1.5 }
    )

    expect(metric.calculate(class_info)).to eq(1.5)
    expect(metric).to be_frozen
    expect { metric.calculate(file_info) }.to raise_error(ArgumentError, /ClassInfo/)
    expect do
      ArchUnit::Metric.new(name: 'bad', subject_type: ArchUnit::ClassInfo, calculation: -> { 1 })
    end.to raise_error(ArgumentError, /Symbol/)
    expect do
      ArchUnit::Metric.new(name: :bad, subject_type: :class, calculation: -> { 1 })
    end.to raise_error(ArgumentError, /Class/)
    expect do
      ArchUnit::Metric.new(name: :bad, subject_type: ArchUnit::ClassInfo, calculation: nil)
    end.to raise_error(ArgumentError, /respond to call/)
    expect do
      ArchUnit::Metric.new(
        name: :bad, subject_type: ArchUnit::ClassInfo, calculation: ->(_subject) { 'one' }
      ).calculate(class_info)
    end.to raise_error(TypeError, /Numeric/)
  end
end
