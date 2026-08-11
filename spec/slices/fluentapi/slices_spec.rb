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

  def intended_diagram(include_retrieval: false)
    <<~PLANTUML
      @startuml
        component [api]
        component [services]
        component [retrieval]
        component [models]
        component [orphan]
        [api] --> [services]
      #{retrieval_dependency(include_retrieval)}  [services] --> [models]
      @enduml
    PLANTUML
  end

  def retrieval_dependency(included)
    included ? "  [api] --> [retrieval]\n" : ''
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

  it 'excludes paths from pattern and regular-expression slice selectors' do
    create_file('lib/app/generated/legacy.rb', "require_relative '../models/item'\n")
    pattern = ArchUnit.project_slices(@project_root).defined_by(
      'lib/app/(**)/', except: { in_folder: 'lib/app/generated' }
    )
    regexp = ArchUnit.project_slices(@project_root).defined_by_regex(
      %r{\Alib/app/([^/]+)/}, except: 'lib/app/generated/**'
    )

    expect(pattern.projection.label_for('lib/app/api/entry.rb')).to eq('api')
    expect(pattern.projection.label_for('lib/app/generated/legacy.rb')).to be_nil
    expect(regexp.projection.label_for('lib/app/generated/legacy.rb')).to be_nil
    expect(pattern.to_plantuml).not_to include('generated')
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

  it 'reports internal and external dependencies missing from a strict diagram' do
    rule = slices.should.adhere_to_diagram(intended_diagram)

    expect(rule.check.map(&:target_slice)).to contain_exactly('retrieval', 'json')
    expect(rule).not_to pass
  end

  it 'ignores external slices without hiding disallowed internal dependencies' do
    rule = slices.should
                 .ignoring_external_slices
                 .adhere_to_diagram(intended_diagram)

    expect(rule.check).to contain_exactly(
      have_attributes(
        source_slice: 'api', target_slice: 'retrieval',
        rule: :adhere_to_diagram, negated?: false
      )
    )
  end

  it 'ignores undeclared orphan endpoints when explicitly requested' do
    diagram = <<~PLANTUML
      @startuml
        component [api]
        component [services]
        component [models]
        [api] --> [services]
        [services] --> [models]
      @enduml
    PLANTUML
    rule = slices.should.ignoring_orphan_slices.adhere_to_diagram(diagram)

    expect(rule).to pass
  end

  it 'loads a file-backed diagram only when check executes' do
    path = @project_root.join('docs', 'architecture.puml')
    rule = slices.should
                 .ignoring_external_slices
                 .adhere_to_diagram_in_file(path)

    expect { rule }.not_to raise_error
    expect { rule.check }.to raise_error(Errno::ENOENT)

    FileUtils.mkdir_p(path.dirname)
    path.write(intended_diagram(include_retrieval: true))
    expect(rule).to pass
  end

  it 'generates and exports a stable PlantUML diagram from the actual slice graph' do
    rendered = slices.to_plantuml

    expect(rendered).to include(
      'component [api]', 'component [orphan]', 'component [json]',
      '[api] --> [retrieval]', '[api] --> [json]', '[services] --> [models]'
    )
    path = @project_root.join('tmp', 'architecture.puml')
    expect(slices.export_as_plantuml(path, ArchUnit::CheckOptions.new(clear_cache: true))).to be_nil
    expect(path.binread.force_encoding(Encoding::UTF_8)).to eq(rendered)
  end

  it 'applies the universal empty-test guard to diagram rules' do
    rule = ArchUnit.project_slices(@project_root)
                   .defined_by('missing/(**)/')
                   .should.adhere_to_diagram(intended_diagram)

    expect(rule.check).to contain_exactly(be_a(ArchUnit::EmptyTestViolation))
  end

  it 'validates locators, projections, scopes, and slice names at build time' do
    expect { ArchUnit.project_slices(Object.new) }.to raise_error(ArgumentError, /project_locator/)
    expect do
      ArchUnit::Slices::FluentApi::SliceScopeBuilder.new(projection: Object.new)
    end.to raise_error(ArgumentError, /SliceProjection/)
    expect do
      ArchUnit::Slices::FluentApi::NegativeSliceConditionBuilder.new(Object.new)
    end.to raise_error(ArgumentError, /SliceScopeBuilder/)
    expect do
      ArchUnit::Slices::FluentApi::ForbiddenSliceDependencyCondition.new(
        Object.new, source_slice: 'api', target_slice: 'models'
      )
    end.to raise_error(ArgumentError, /SliceScopeBuilder/)
    expect { slices.should_not.contain_dependency('', 'models') }
      .to raise_error(ArgumentError, /source_slice/)
    expect do
      ArchUnit::Slices::FluentApi::PositiveSliceConditionBuilder.new(
        slices, options: Object.new
      )
    end.to raise_error(ArgumentError, /DiagramAdherenceOptions/)
    expect do
      ArchUnit::Slices::FluentApi::PositiveSliceConditionBuilder.new(Object.new)
    end.to raise_error(ArgumentError, /SliceScopeBuilder/)
    expect { slices.should.adhere_to_diagram('') }
      .to raise_error(ArgumentError, /diagram source/)
    source = ArchUnit::Slices::FluentApi::DiagramSource.inline('@startuml\n@enduml')
    options = ArchUnit::DiagramAdherenceOptions.new
    expect do
      ArchUnit::Slices::FluentApi::DiagramSliceCondition.new(
        Object.new, source, options:
      )
    end.to raise_error(ArgumentError, /SliceScopeBuilder/)
    expect do
      ArchUnit::Slices::FluentApi::DiagramSliceCondition.new(
        slices, Object.new, options:
      )
    end.to raise_error(ArgumentError, /DiagramSource/)
    expect do
      ArchUnit::Slices::FluentApi::DiagramSliceCondition.new(
        slices, source, options: Object.new
      )
    end.to raise_error(ArgumentError, /DiagramAdherenceOptions/)
    expect do
      ArchUnit::Slices::FluentApi::DiagramSource.new(kind: :remote, value: 'diagram')
    end.to raise_error(ArgumentError, /kind/)
    expect(
      ArchUnit::Slices::FluentApi::DiagramSource.file('architecture.puml').value
    ).to eq('architecture.puml')
  end
end
