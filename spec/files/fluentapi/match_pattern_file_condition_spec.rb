# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe ArchUnit::Files::FluentApi::MatchPatternFileCondition do
  around do |example|
    Dir.mktmpdir('archunit-files-pattern') do |directory|
      @project_root = Pathname.new(directory).realpath
      @project_root.join('Gemfile').write('')
      ArchUnit.clear_graph_cache
      example.run
      ArchUnit.clear_graph_cache
    end
  end

  def create_file(relative_path)
    path = @project_root.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    path.write('# fixture')
    path
  end

  before do
    create_file('lib/services/order_service.rb')
    create_file('lib/repositories/order_repository.rb')
    create_file('spec/order_service_spec.rb')
  end

  it 'excludes files from a selector in the same fluent call' do
    create_file('lib/generated/legacy_client.rb')
    rule = ArchUnit.files(@project_root)
                   .in_path('lib/**/*.rb', except: { in_folder: 'lib/generated' })
                   .should.have_name('*_service.rb')

    expect(rule.check.map { |violation| violation.projected_node.label }).to eq(
      ['lib/repositories/order_repository.rb']
    )
  end

  it 'checks positive and negated filename predicates with one shared terminal' do
    scope = ArchUnit.project_files(@project_root).in_path('lib/**/*.rb')
    positive = scope.should.have_name('*_service.rb')
    negative = scope.should_not.have_name('*_repository.rb')

    expect(positive).to be_a(ArchUnit::Checkable)
    expect(positive).to be_frozen
    expect(positive.check.map { |violation| violation.projected_node.label }).to eq(
      ['lib/repositories/order_repository.rb']
    )
    expect(negative.check.map { |violation| violation.projected_node.label }).to eq(
      ['lib/repositories/order_repository.rb']
    )
    expect(negative.check).to all(be_negated)
  end

  it 'checks folder predicates against paths without filenames' do
    rule = ArchUnit.files(@project_root).in_path('lib/**/*.rb')
                   .should.be_in_folder('lib/services')

    expect(rule.check.map { |violation| violation.projected_node.label }).to eq(
      ['lib/repositories/order_repository.rb']
    )
  end

  it 'checks full-path predicates and honors the preselected scope' do
    passing = ArchUnit.files(@project_root).in_folder('lib/services')
                      .should.be_in_path('lib/services/**')
    negated = ArchUnit.files(@project_root).in_folder('lib/services')
                      .should_not.be_in_path('spec/**')

    expect(passing.check).to eq([])
    expect(negated.check).to eq([])
  end

  it 'supports regular expressions for predicate patterns' do
    rule = ArchUnit.files(@project_root).in_folder('lib/services')
                   .should.have_name(/service\.rb\z/)

    expect(rule.check).to eq([])
  end

  it 'returns a mood-aware empty-test violation unless allowed' do
    rule = ArchUnit.files(@project_root).in_folder('missing/**')
                   .should_not.have_name('*.rb')

    expect(rule.check).to contain_exactly(
      ArchUnit::EmptyTestViolation.new(filters: rule.filters, is_negated: true)
    )
    expect(rule.check(ArchUnit::CheckOptions.new(allow_empty_tests: true))).to eq([])
  end

  it 'exposes all three predicates in both moods and no further scope stage' do
    positive = ArchUnit.files(@project_root).should
    negative = ArchUnit.files(@project_root).should_not

    expect(positive).to respond_to(:have_name, :be_in_folder, :be_in_path)
    expect(negative).to respond_to(:have_name, :be_in_folder, :be_in_path)
    expect(positive.have_name('*.rb')).not_to respond_to(:in_folder)
  end
end
