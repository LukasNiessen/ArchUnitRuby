# frozen_string_literal: true

require 'fileutils'
require 'minitest'
require 'pathname'
require 'tmpdir'

RSpec.describe 'Rule rationale' do
  around do |example|
    Dir.mktmpdir('archunit-rationale') do |directory|
      @root = Pathname.new(directory).realpath
      @root.join('Gemfile').write('')
      FileUtils.mkdir_p(@root.join('app/api'))
      FileUtils.mkdir_p(@root.join('app/database'))
      @root.join('app/api/request.rb').write("require_relative '../database/store'\n")
      @root.join('app/database/store.rb').write('class Store; end')
      ArchUnit.clear_graph_cache
      example.run
    ensure
      ArchUnit.clear_graph_cache
    end
  end

  let(:reason) { 'Keep persistence out of the API' }
  let(:rule) do
    ArchUnit.project_files(@root).in_folder('app/api/**')
            .should_not.depend_on_files.in_folder('app/database/**')
  end

  # rubocop:disable-next Metrics/AbcSize, Metrics/MethodLength -- One fixture covers every terminal.
  def all_terminals
    files = ArchUnit.project_files(@root)
    metrics = ArchUnit.metrics(@root)
    slices = ArchUnit.project_slices(@root).defined_by('app/(**)/')
    [
      files.should.have_name('*.rb'),
      files.should.have_no_cycles,
      files.should_not.depend_on_files.in_folder('app/database/**'),
      files.should_not.depend_on_external_modules.matching('json'),
      files.should.adhere_to(->(_file) { true }, 'Ruby files'),
      ArchUnit.project_layers(@root).layer('api').defined_by('app/api/**')
              .where_layer('api').may_only_depend_on_layers,
      slices.should_not.contain_dependency('api', 'database'),
      slices.should.adhere_to_diagram(slices.to_plantuml),
      metrics.count.classes.should_be_above(0),
      metrics.count.classes.should_satisfy(->(value, _info) { value >= 0 }),
      metrics.custom_metric('members', 'member count', ->(info) { info.methods.length })
             .should_satisfy(->(value, _info) { value >= 0 }),
      metrics.distance.not_in_zone_of_pain
    ]
  end

  it 'supports every concrete terminal through one immutable common contract' do
    terminals = all_terminals
    classes = ObjectSpace.each_object(Class).select do |candidate|
      candidate.name&.start_with?('ArchUnit::') && candidate.include?(ArchUnit::Checkable)
    end
    expect(terminals.map(&:class).uniq).to match_array(classes)

    terminals.each do |original|
      explained = original.because("  #{reason}  ")
      expect(explained).to be_a(original.class)
      expect(explained).not_to equal(original)
      expect(explained).to be_frozen
      expect(explained.rationale).to eq(reason)
      expect(explained.rationale).to be_frozen
      expect(original.rationale).to be_nil
      expect(ArchUnit.format_violations(explained.check, color: false))
        .to eq(ArchUnit.format_violations(original.check, color: false))
    end
  end

  it 'owns its normalized string, supports replacement, and leaves caller values reusable' do
    input = "  #{reason}  "
    explained = rule.because(input)
    input.replace('changed')
    replacement = explained.because('A different explanation')

    expect(explained.rationale).to eq(reason)
    expect(replacement.rationale).to eq('A different explanation')
    expect(rule.rationale).to be_nil
  end

  it 'rejects blank and non-string reasons' do
    [nil, false, 42, :reason, '', " \t\n "].each do |invalid|
      expect { rule.because(invalid) }.to raise_error(ArgumentError, /non-empty String/)
    end
  end

  it 'does no analysis while copying a rule' do
    rule.check
    expect(Prism).not_to receive(:parse)
    expect(ArchUnit::Extraction).not_to receive(:extract_graph)
    explained = rule.because(reason)
    expect(explained.rationale).to eq(reason)
  end

  it 'preserves graph cache identity and structured violations' do
    violations = rule.check
    graph = ArchUnit::Extraction.extract_graph(@root)
    explained = rule.because(reason)
    expect(explained.check).to eq(violations)
    expect(ArchUnit::Extraction.extract_graph(@root)).to equal(graph)
    expect(ArchUnit.format_violations(violations)).not_to include(reason)
  end

  it 'includes the reason exactly once in framework-neutral and RSpec failures' do
    explained = rule.because(reason)
    expect { ArchUnit.assert_passes(explained) }
      .to raise_error(ArchUnit::AssertionFailure) do |error|
        expect(error.message.scan(reason).length).to eq(1)
      end
    expect { expect(explained).to pass }
      .to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
        expect(error.message.scan(reason).length).to eq(1)
      end
    expect(explained).not_to pass
  end

  it 'includes the reason exactly once in Minitest failures' do
    ArchUnit::Testing::MinitestAdapter.install!
    context = Class.new do
      include Minitest::Assertions

      attr_accessor :assertions
    end.new
    context.assertions = 0

    expect { context.assert_passes(rule.because(reason)) }
      .to raise_error(Minitest::Assertion) do |error|
        expect(error.message.scan(reason).length).to eq(1)
      end
    expect(context.assertions).to eq(1)
  end

  it 'explains failed negated expectations but not successful assertions' do
    passing = ArchUnit.project_files(@root).should.have_no_cycles.because(reason)
    expect(passing).to pass
    expect(ArchUnit.assert_passes(passing)).to be_nil
    expect(ArchUnit::Testing.result_for(passing).message).not_to include(reason)
    expect(ArchUnit::Testing.result_for(rule.because(reason), expected_to_pass: false).message)
      .not_to include(reason)
    expect { expect(passing).not_to pass }
      .to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
        expect(error.message).to include('Expected architecture violations')
        expect(error.message.scan(reason).length).to eq(1)
      end
  end
end
