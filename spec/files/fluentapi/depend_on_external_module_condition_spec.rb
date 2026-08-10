# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe ArchUnit::Files::FluentApi::DependOnExternalModuleCondition do
  around do |example|
    Dir.mktmpdir('archunit-external-dependency') do |directory|
      @project_root = Pathname.new(directory).realpath
      @project_root.join('Gemfile').write('')
      ArchUnit.clear_graph_cache
      example.run
      ArchUnit.clear_graph_cache
    end
  end

  def create_file(relative_path, contents = '# fixture')
    path = @project_root.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    path.write(contents)
    path
  end

  before do
    create_file(
      'lib/clients/api_client.rb',
      "require 'json'\nrequire 'net/http'\n"
    )
    create_file('lib/services/order_service.rb', "require 'set'\n")
  end

  it 'reports forbidden external modules in the negated mood' do
    rule = ArchUnit.files(@project_root)
                   .in_folder('lib/clients')
                   .should_not.depend_on_external_modules
                   .matching('json')

    expect(rule).to be_a(ArchUnit::Checkable)
    expect(rule.check.map { |violation| violation.dependency.target_label }).to eq(['json'])
    expect(rule.check).to all(be_negated)
  end

  it 'uses the positive mood as an external-module allowlist' do
    rule = ArchUnit.files(@project_root)
                   .in_folder('lib/clients')
                   .should.depend_on_external_modules
                   .matching('json')

    expect(rule.check.map { |violation| violation.dependency.target_label }).to eq(['net/http'])
  end

  it 'chains immutable matching selectors with OR semantics' do
    module_stage = ArchUnit.files(@project_root)
                           .in_folder('lib/clients')
                           .should_not.depend_on_external_modules
    json_rule = module_stage.matching('json')
    combined_rule = json_rule.matching('net/**')

    expect(module_stage).to be_frozen
    expect(json_rule).to be_frozen
    expect(combined_rule).to be_frozen
    expect(json_rule.module_filters.length).to eq(1)
    expect(combined_rule.module_filters.length).to eq(2)
    expect(combined_rule.check.map { |violation| violation.dependency.target_label })
      .to contain_exactly('json', 'net/http')
  end

  it 'supports regular expressions for module names' do
    rule = ArchUnit.files(@project_root)
                   .in_folder('lib/clients')
                   .should_not.depend_on_external_modules
                   .matching(%r{\Anet/})

    expect(rule.check.map { |violation| violation.dependency.target_label }).to eq(['net/http'])
  end

  it 'returns a mood-aware empty-test violation for an empty subject scope' do
    rule = ArchUnit.files(@project_root)
                   .in_folder('missing/**')
                   .should.depend_on_external_modules
                   .matching('json')

    expect(rule.check).to contain_exactly(
      ArchUnit::EmptyTestViolation.new(filters: rule.subject_filters)
    )
    expect(rule.check(ArchUnit::CheckOptions.new(allow_empty_tests: true))).to eq([])
  end

  it 'exposes the external predicate in both moods' do
    positive = ArchUnit.files(@project_root).should
    negative = ArchUnit.files(@project_root).should_not

    expect(positive).to respond_to(:depend_on_external_modules)
    expect(negative).to respond_to(:depend_on_external_modules)
    expect(positive.depend_on_external_modules).to respond_to(:matching)
  end
end
