# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe 'slice dependency rules' do
  around do |example|
    Dir.mktmpdir('archunit-slices') do |directory|
      @project_root = Pathname.new(directory).realpath
      @project_root.join('Gemfile').write('')
      create_file(
        'lib/app/api/entry.rb',
        "require_relative '../services/worker'\n" \
        "require_relative '../retrieval/repository'\nrequire 'json'\n"
      )
      create_file('lib/app/services/worker.rb', "require_relative '../models/item'\n")
      create_file('lib/app/retrieval/repository.rb')
      create_file('lib/app/models/item.rb')
      create_file('lib/app/orphan/lonely.rb')
      ArchUnit.clear_graph_cache
      example.run
      ArchUnit.clear_graph_cache
    end
  end

  def create_file(relative_path, contents = '# fixture')
    path = @project_root.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    path.write(contents)
  end

  def slices
    ArchUnit.project_slices(@project_root).defined_by('lib/app/(**)/')
  end

  it 'builds immutable scopes and moods without extracting the graph' do
    expect(ArchUnit::Extraction).not_to receive(:extract_graph)

    base = ArchUnit.slices(@project_root)
    pattern = base.defined_by('lib/app/(**)/')
    regexp = base.defined_by_regex(%r{\Alib/app/([^/]+)/})
    mood = pattern.should_not
    rule = mood.contain_dependency('api', 'retrieval')

    expect([base, pattern, regexp, mood, rule]).to all(be_frozen)
    expect(base.projection.label_for('lib/app/api/entry.rb')).to eq('lib/app/api/entry.rb')
    expect(pattern.projection.label_for('lib/app/api/entry.rb')).to eq('api')
    expect(regexp.projection.label_for('lib/app/api/entry.rb')).to eq('api')
    expect(rule).to be_a(ArchUnit::Checkable)
    expect(rule).to be_negated
  end

  it 'reports a forbidden slice dependency with every concrete edge as evidence' do
    rule = slices.should_not.contain_dependency('api', 'retrieval')

    expect(rule.check).to contain_exactly(
      have_attributes(
        source_slice: 'api', target_slice: 'retrieval',
        rule: :contain_dependency, negated?: true,
        dependency: have_attributes(
          source_label: 'api', target_label: 'retrieval',
          cumulated_edges: contain_exactly(
            have_attributes(
              source: 'lib/app/api/entry.rb',
              target: 'lib/app/retrieval/repository.rb'
            )
          )
        )
      )
    )
    expect(rule).not_to pass
  end

  it 'passes when a forbidden slice dependency is absent' do
    expect(slices.should_not.contain_dependency('models', 'api')).to pass
  end

  it 'can forbid a dependency from an internal slice to an external module' do
    violations = slices.should_not.contain_dependency('api', 'json').check

    expect(violations).to contain_exactly(
      have_attributes(
        source_slice: 'api', target_slice: 'json',
        dependency: have_attributes(
          cumulated_edges: contain_exactly(have_attributes(external: true, target: 'json'))
        )
      )
    )
  end

  it 'guards a slice definition that selects no project files' do
    rule = ArchUnit.project_slices(@project_root)
                   .defined_by('missing/(**)/')
                   .should_not.contain_dependency('api', 'retrieval')

    expect(rule.check).to contain_exactly(be_a(ArchUnit::EmptyTestViolation).and(be_negated))
    expect(rule.check(ArchUnit::CheckOptions.new(allow_empty_tests: true))).to eq([])
  end

  it 'validates locators, projections, scopes, and slice names at build time' do
    expect { ArchUnit.project_slices(Object.new) }.to raise_error(ArgumentError, /project_locator/)
    expect do
      ArchUnit::Slices::FluentApi::SliceScopeBuilder.new(projection: Object.new)
    end.to raise_error(ArgumentError, /SliceProjection/)
    expect do
      ArchUnit::Slices::FluentApi::NegativeSliceConditionBuilder.new(Object.new)
    end.to raise_error(ArgumentError, /SliceScopeBuilder/)
    expect { slices.should_not.contain_dependency('', 'models') }
      .to raise_error(ArgumentError, /source_slice/)
  end
end
