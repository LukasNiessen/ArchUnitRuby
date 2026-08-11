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

  # rubocop:disable Metrics/MethodLength -- Four files create both distance zones.
  def build_distance_project(root)
    write_source(root, 'lib/stable.rb', <<~RUBY)
      class Stable
      end
    RUBY
    %w[first second].each do |name|
      write_source(root, "lib/#{name}.rb", <<~RUBY)
        require_relative 'stable'
        class #{name.capitalize}
        end
      RUBY
    end
    write_source(root, 'lib/contract.rb', <<~RUBY)
      require_relative 'stable'
      module Contract
        def perform
          raise NotImplementedError
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

  it 'applies file and class exclusions before measuring a scope' do
    Dir.mktmpdir do |root|
      build_project(root)

      files = ArchUnit.metrics(root)
                      .in_path('lib/**/*.rb', except: { in_folder: 'lib/services' })
                      .count.classes.measure
      classes = ArchUnit.metrics(root)
                        .for_classes_matching('*', except: 'Sales::*')
                        .count.method_count.measure

      expect(files.map(&:identifier)).to eq(['lib/models/order.rb'])
      expect(classes.map(&:identifier)).to eq(['lib/services/pay.rb:PayService'])
    end
  end

  it 'does not retain non-matching classes from a selected multi-class file' do
    Dir.mktmpdir do |root|
      write_source(root, 'lib/mixed.rb', <<~RUBY)
        class SelectedService
        end

        class UnrelatedModel
        end
      RUBY

      analysis = ArchUnit.metrics(root).for_classes_matching('*Service').analyze

      expect(analysis.files.map(&:path)).to eq(['lib/mixed.rb'])
      expect(analysis.classes.map(&:name)).to eq(['SelectedService'])
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

  it 'measures all distance variants over selected files' do
    Dir.mktmpdir do |root|
      build_distance_project(root)
      scope = ArchUnit.metrics(root).with_name('stable.rb')

      measurements = ArchUnit::DistanceMetrics::CALCULATIONS.each_key.to_h do |name|
        [name, scope.distance.public_send(name).measure.fetch(0).value]
      end

      expect(measurements).to include(
        abstractness: 0.0, instability: 0.0,
        distance_from_main_sequence: 1.0, coupling_factor: 0.5
      )
      expect(measurements[:normalized_distance]).to be_between(0.0, 1.0)
    end
  end

  it 'executes both architectural zone guards and formats their evidence' do
    Dir.mktmpdir do |root|
      build_distance_project(root)
      pain_rule = ArchUnit.metrics(root).with_name('stable.rb').distance.not_in_zone_of_pain
      useless_rule = ArchUnit.metrics(root).with_name('contract.rb')
                             .distance.not_in_zone_of_uselessness

      expect(pain_rule).to be_a(ArchUnit::Checkable)
      expect(pain_rule.check).to contain_exactly(
        have_attributes(zone: :pain, distance_info: have_attributes(path: 'lib/stable.rb'))
      )
      expect(useless_rule.check).to contain_exactly(
        have_attributes(
          zone: :uselessness, distance_info: have_attributes(path: 'lib/contract.rb')
        )
      )
      formatted = ArchUnit::ViolationFactory.from_violation(pain_rule.check.fetch(0))
      expect(formatted).to have_attributes(
        message: 'Metric zone violation',
        details: include("File 'lib/stable.rb'", 'abstractness=0.00', 'instability=0.00')
      )
    end
  end

  it 'guards an empty distance scope unless explicitly allowed' do
    Dir.mktmpdir do |root|
      build_distance_project(root)
      rule = ArchUnit.metrics(root).with_name('missing.rb').distance.not_in_zone_of_pain

      expect(rule.check).to contain_exactly(an_instance_of(ArchUnit::EmptyTestViolation))
      expect(
        rule.check(ArchUnit::CheckOptions.new(allow_empty_tests: true))
      ).to be_empty
    end
  end

  it 'measures a named custom metric over the selected full ClassInfo values' do
    Dir.mktmpdir do |root|
      build_project(root)
      custom = ArchUnit.metrics(root).for_classes_matching('Pay*').custom_metric(
        'member count', 'Total methods and fields',
        ->(info) { info.methods.length + info.fields.length }
      )

      measurement = custom.measure.fetch(0)

      expect(measurement).to have_attributes(
        identifier: 'lib/services/pay.rb:PayService',
        metric_name: 'member count', value: 2
      )
      expect(measurement.metric_name).to be_frozen
    end
  end

  it 'executes a custom should_satisfy predicate with value and ClassInfo evidence' do
    Dir.mktmpdir do |root|
      build_project(root)
      received = []
      rule = ArchUnit.metrics(root).for_classes_matching('Pay*').custom_metric(
        'member count', 'Classes should have fewer than two members',
        ->(info) { info.methods.length + info.fields.length }
      ).should_satisfy(lambda do |value, info|
        received << [value, info]
        value < 2
      end)

      expect(rule).to be_a(ArchUnit::Checkable)
      expect(rule.check).to contain_exactly(
        have_attributes(
          metric_name: 'member count', value: 2,
          class_info: have_attributes(name: 'PayService')
        )
      )
      expect(received).to contain_exactly([2, an_instance_of(ArchUnit::ClassInfo)])
    end
  end

  it 'guards empty custom metric predicates while allowing empty measurements' do
    Dir.mktmpdir do |root|
      build_project(root)
      custom = ArchUnit.metrics(root).for_classes_matching('Missing*').custom_metric(
        'methods', 'Method count', ->(info) { info.methods.length }
      )
      rule = custom.should_satisfy(->(_value, _info) { true })

      expect(custom.measure).to be_empty
      expect(rule.check).to contain_exactly(an_instance_of(ArchUnit::EmptyTestViolation))
      expect(
        rule.check(ArchUnit::CheckOptions.new(allow_empty_tests: true))
      ).to be_empty
    end
  end

  it 'exposes exactly the six shared threshold verbs on every metric selection' do
    scope = ArchUnit.metrics
    selections = [
      scope.count.method_count,
      scope.lcom.lcom4,
      scope.distance.instability,
      scope.custom_metric('score', 'Example score', ->(_info) { 1 })
    ]
    expected = %i[
      should_be_below should_be_above should_be should_be_below_or_equal
      should_be_above_or_equal should_satisfy
    ]

    expect(selections).to all(
      satisfy { |selection| expected.all? { |name| selection.respond_to?(name) } }
    )
    expect(selections).to all(
      satisfy do |selection|
        %i[should_equal should_be_at_most should_be_less_than].none? do |name|
          selection.respond_to?(name)
        end
      end
    )
  end

  it 'executes exact thresholds for class, file, distance, and custom metrics' do
    Dir.mktmpdir do |root|
      build_project(root)
      scope = ArchUnit.metrics(root)
      rules = [
        scope.for_classes_matching('Pay*').count.method_count.should_be(1),
        scope.with_name('order.rb').count.classes.should_be_above_or_equal(1),
        scope.with_name('order.rb').distance.abstractness.should_be_below_or_equal(1.0),
        scope.for_classes_matching('Pay*').custom_metric(
          'members', 'Total members', ->(info) { info.methods.length + info.fields.length }
        ).should_be_above(1)
      ]

      expect(rules).to all(be_a(ArchUnit::Checkable))
      expect(rules.flat_map(&:check)).to be_empty
      failing = scope.for_classes_matching('Pay*').count.method_count.should_be_below(1)
      expect(failing.check).to contain_exactly(
        have_attributes(
          identifier: 'lib/services/pay.rb:PayService', metric_name: :method_count,
          value: 1, threshold: 1, comparison: :below
        )
      )
      expect(ArchUnit::ViolationFactory.from_violation(failing.check.fetch(0))).to have_attributes(
        message: 'Metric threshold violation', details: include('expected below 1')
      )
    end
  end

  it 'executes should_satisfy for built-in metrics with value and subject evidence' do
    Dir.mktmpdir do |root|
      build_project(root)
      received = []
      predicate = lambda do |value, subject|
        received << [value, subject.name]
        false
      end
      selection = ArchUnit.metrics(root).for_classes_matching('Pay*').lcom.lcom4
      rule = selection.should_satisfy(predicate)

      expect(rule.check).to contain_exactly(
        have_attributes(
          identifier: 'lib/services/pay.rb:PayService', metric_name: :lcom4, value: 1
        )
      )
      expect(received).to eq([[1, 'PayService']])
      expect(ArchUnit::ViolationFactory.from_violation(rule.check.fetch(0))).to have_attributes(
        message: 'Metric predicate violation', details: include('predicate returned false')
      )
    end
  end

  it 'guards empty threshold scopes unless explicitly allowed' do
    Dir.mktmpdir do |root|
      build_project(root)
      rule = ArchUnit.metrics(root).for_classes_matching('Missing*')
                     .count.method_count.should_be_below(10)

      expect(rule.check).to contain_exactly(an_instance_of(ArchUnit::EmptyTestViolation))
      expect(rule.check(ArchUnit::CheckOptions.new(allow_empty_tests: true))).to be_empty
    end
  end

  it 'exports scoped count, LCOM, and distance builders as HTML reports' do
    Dir.mktmpdir do |root|
      build_distance_project(root)
      scope = ArchUnit.metrics(root).with_name('stable.rb')
      options = ArchUnit::MetricsExportOptions.new(
        title: 'Stable Metrics', include_timestamp: false
      )
      reports = {
        count: scope.count,
        lcom: ArchUnit.metrics(root).for_classes_matching('Stable').lcom,
        distance: scope.distance
      }

      reports.each do |name, builder|
        output = File.join(root, 'reports', name.to_s)
        expect(builder.export_as_html(output, options)).to be_nil
        html = File.read("#{output}.html")
        expect(html).to include('<title>Stable Metrics</title>', 'Generated by ArchUnitRuby')
      end

      expect(File.read(File.join(root, 'reports', 'count.html'))).to include(
        'classes [lib/stable.rb]', 'lines_of_code [lib/stable.rb]'
      )
      expect(File.read(File.join(root, 'reports', 'lcom.html'))).to include(
        'lcom4 [lib/stable.rb:Stable]'
      )
      expect(File.read(File.join(root, 'reports', 'distance.html'))).to include(
        'instability [lib/stable.rb]', 'distance_from_main_sequence [lib/stable.rb]'
      )
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
    expect { described_class::DistanceMetricsBuilder.new(:bad) }
      .to raise_error(ArgumentError, /MetricsBuilder/)
    expect { described_class::ZoneCondition.new(scope: builder, zone: :bad) }
      .to raise_error(ArgumentError, /unknown architectural zone/)
    expect { builder.custom_metric('', 'description', ->(_info) { 1 }) }
      .to raise_error(ArgumentError, /custom metric name/)
    expect { builder.custom_metric('score', '', ->(_info) { 1 }) }
      .to raise_error(ArgumentError, /description/)
    custom = builder.custom_metric('score', 'description', ->(_info) { 1 })
    expect { custom.should_satisfy(nil) }.to raise_error(ArgumentError, /predicate/)
    expect { described_class::CustomMetricCondition.new(selection: :bad, predicate: -> {}) }
      .to raise_error(ArgumentError, /CustomMetricBuilder/)
    expect { described_class::MetricSelection.new(scope: :bad, metric:) }
      .to raise_error(ArgumentError, /MetricsBuilder/)
    expect { described_class::MetricSelection.new(scope: builder, metric: :bad) }
      .to raise_error(ArgumentError, /Metric/)
    selection = described_class::MetricSelection.new(scope: builder, metric:)
    expect { selection.should_be_below(Float::INFINITY) }
      .to raise_error(ArgumentError, /finite real Numeric/)
    expect { selection.should_satisfy(nil) }.to raise_error(ArgumentError, /predicate/)
    expect do
      described_class::MetricThresholdCondition.new(
        selection: :bad, comparison: :below, threshold: 1
      )
    end.to raise_error(ArgumentError, /MetricSelection/)
    expect do
      described_class::MetricThresholdCondition.new(
        selection:, comparison: :unknown, threshold: 1
      )
    end.to raise_error(ArgumentError, /unknown metric comparison/)
    expect do
      described_class::MetricPredicateCondition.new(selection: :bad, predicate: -> {})
    end.to raise_error(ArgumentError, /MetricSelection/)
    expect do
      described_class::MetricMeasurement.new(subject: :bad, metric_name: :count, value: 1)
    end.to raise_error(ArgumentError, /identifier/)
    expect do
      described_class::MetricMeasurement.new(subject:, metric_name: '', value: 1)
    end.to raise_error(ArgumentError, /metric_name/)
    expect do
      described_class::MetricMeasurement.new(subject:, metric_name: :count, value: '1')
    end.to raise_error(ArgumentError, /finite real Numeric/)
    expect do
      described_class::MetricMeasurement.new(
        subject:, metric_name: :count, value: Float::NAN
      )
    end.to raise_error(ArgumentError, /finite real Numeric/)
  end
end
