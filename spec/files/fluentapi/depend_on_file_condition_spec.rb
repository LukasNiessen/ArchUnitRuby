# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe ArchUnit::Files::FluentApi::DependOnFileCondition do
  around do |example|
    Dir.mktmpdir('archunit-files-dependency') do |directory|
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
      'lib/controllers/order_controller.rb',
      "require_relative '../services/order_service'\nrequire_relative '../shared/logger'\n"
    )
    create_file('lib/services/order_service.rb')
    create_file('lib/shared/logger.rb')
  end

  it 'reports forbidden internal dependencies in the negated mood' do
    rule = ArchUnit.files(@project_root)
                   .in_folder('lib/controllers')
                   .should_not.depend_on_files
                   .in_folder('lib/services')

    expect(rule).to be_a(ArchUnit::Checkable)
    expect(rule.check.map { |violation| violation.dependency.target_label }).to eq(
      ['lib/services/order_service.rb']
    )
    expect(rule.check).to all(be_negated)
  end

  it 'uses the positive mood as an allowlist for outgoing dependencies' do
    rule = ArchUnit.files(@project_root)
                   .in_folder('lib/controllers')
                   .should.depend_on_files
                   .in_folder('lib/services')

    expect(rule.check.map { |violation| violation.dependency.target_label }).to eq(
      ['lib/shared/logger.rb']
    )
  end

  it 'chains immutable object selectors with AND semantics' do
    object_stage = ArchUnit.files(@project_root).should_not.depend_on_files
    folder_rule = object_stage.in_folder('lib/services')
    named_rule = folder_rule.with_name('*_service.rb')

    expect(object_stage).to be_frozen
    expect(folder_rule).to be_frozen
    expect(named_rule).to be_frozen
    expect(folder_rule.object_filters.length).to eq(1)
    expect(named_rule.object_filters.length).to eq(2)
    expect(named_rule.check.length).to eq(1)
  end

  it 'supports regular expressions in object selectors' do
    rule = ArchUnit.files(@project_root)
                   .in_folder('lib/controllers')
                   .should_not.depend_on_files
                   .in_path(%r{services/.+_service\.rb\z})

    expect(rule.check.length).to eq(1)
  end

  it 'returns a mood-aware empty-test violation for an empty subject scope' do
    rule = ArchUnit.files(@project_root)
                   .in_folder('missing/**')
                   .should_not.depend_on_files
                   .in_folder('lib/services')

    expect(rule.check).to contain_exactly(
      ArchUnit::EmptyTestViolation.new(filters: rule.subject_filters, is_negated: true)
    )
    expect(rule.check(ArchUnit::CheckOptions.new(allow_empty_tests: true))).to eq([])
  end

  it 'exposes the relational predicate in both moods' do
    positive = ArchUnit.files(@project_root).should
    negative = ArchUnit.files(@project_root).should_not

    expect(positive).to respond_to(:depend_on_files)
    expect(negative).to respond_to(:depend_on_files)
    expect(positive.depend_on_files).to respond_to(:with_name, :in_folder, :in_path)
  end
end
