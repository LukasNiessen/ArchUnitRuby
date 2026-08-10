# frozen_string_literal: true

require 'tmpdir'

RSpec.describe ArchUnit::Metrics::FluentApi do
  def write_source(root, relative_path, source)
    path = File.join(root, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, source)
  end

  # rubocop:disable Metrics/MethodLength -- Both small files form one reusable fixture project.
  def build_project(root)
    write_source(root, 'lib/models/order.rb', <<~RUBY)
      class Sales::Order
        def total
          @total
        end
      end
    RUBY
    write_source(root, 'lib/services/pay.rb', <<~RUBY)
      class PayService
        def call
          @gateway
        end
      end
    RUBY
  end
  # rubocop:enable Metrics/MethodLength

  it 'builds immutable selectors without touching the filesystem' do
    allow(ArchUnit::MetricExtraction).to receive(:extract_project_info).and_call_original

    original = ArchUnit.metrics('missing-project')
    selected = original.with_name('*.rb').in_folder('models').in_path('lib/**')
                       .for_classes_matching('Sales::*')

    expect(original.filters).to be_empty
    expect(selected.filters.length).to eq(4)
    expect(selected).to be_frozen
    expect(ArchUnit::MetricExtraction).not_to have_received(:extract_project_info)
  end

  it 'analyzes selected files and classes end to end' do
    Dir.mktmpdir do |root|
      build_project(root)

      analysis = ArchUnit.metrics(Pathname.new(root)).in_folder('**/models')
                         .for_classes_matching('Sales::*').analyze

      expect(analysis.files.map(&:path)).to eq(['lib/models/order.rb'])
      expect(analysis.classes.map(&:name)).to eq(['Sales::Order'])
    end
  end

  it 'measures class and file counts over the selected scope' do
    Dir.mktmpdir do |root|
      build_project(root)

      class_measurements = ArchUnit.metrics(root).for_classes_matching('Pay*')
                                   .count.method_count.measure
      file_measurements = ArchUnit.metrics(root).with_name('order.rb')
                                  .count.classes.measure

      expect(class_measurements.map(&:identifier)).to eq(['lib/services/pay.rb:PayService'])
      expect(class_measurements.map(&:value)).to eq([1])
      expect(class_measurements.first.metric_name).to eq(:method_count)
      expect(file_measurements.map(&:identifier)).to eq(['lib/models/order.rb'])
      expect(file_measurements.map(&:value)).to eq([1])
      expect(class_measurements).to be_frozen
    end
  end

  it 'measures every LCOM variant over extracted Ruby method-field relationships' do
    Dir.mktmpdir do |root|
      build_project(root)
      scope = ArchUnit.metrics(root).for_classes_matching('Pay*')

      measurements = ArchUnit::LCOMMetrics::CALCULATIONS.each_key.to_h do |name|
        [name, scope.lcom.public_send(name).measure.fetch(0).value]
      end

      expect(measurements.keys).to eq(
        %i[lcom96a lcom96b lcom1 lcom2 lcom3 lcom4 lcom5 lcom_star]
      )
      expect(measurements[:lcom4]).to eq(1)
    end
  end

  it 'validates builder, metric selection, and measurement inputs' do
    builder = ArchUnit.metrics
    metric = ArchUnit::CountMetrics.method_count
    subject = ArchUnit::ClassInfo.new(name: 'Example', file_path: 'example.rb')

    expect { described_class::MetricsBuilder.new(project_locator: '') }
      .to raise_error(ArgumentError, /project_locator/)
    expect { described_class::MetricsBuilder.new(filters: [:bad]) }
      .to raise_error(ArgumentError, /Filter/)
    expect { described_class::CountMetricsBuilder.new(:bad) }
      .to raise_error(ArgumentError, /MetricsBuilder/)
    expect { described_class::LCOMMetricsBuilder.new(:bad) }
      .to raise_error(ArgumentError, /MetricsBuilder/)
    expect { described_class::MetricSelection.new(scope: :bad, metric:) }
      .to raise_error(ArgumentError, /MetricsBuilder/)
    expect { described_class::MetricSelection.new(scope: builder, metric: :bad) }
      .to raise_error(ArgumentError, /Metric/)
    expect do
      described_class::MetricMeasurement.new(subject: :bad, metric_name: :count, value: 1)
    end.to raise_error(ArgumentError, /identifier/)
    expect do
      described_class::MetricMeasurement.new(subject:, metric_name: 'count', value: 1)
    end.to raise_error(ArgumentError, /metric_name/)
    expect do
      described_class::MetricMeasurement.new(subject:, metric_name: :count, value: '1')
    end.to raise_error(ArgumentError, /Numeric/)
  end
end
