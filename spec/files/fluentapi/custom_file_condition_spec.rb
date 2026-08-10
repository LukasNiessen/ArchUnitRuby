# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe ArchUnit::Files::FluentApi::CustomFileCondition do
  around do |example|
    Dir.mktmpdir('archunit-custom-file') do |directory|
      @project_root = Pathname.new(directory).realpath
      @project_root.join('Gemfile').write('')
      ArchUnit.clear_graph_cache
      example.run
      ArchUnit.clear_graph_cache
    end
  end

  def create_file(relative_path, contents)
    path = @project_root.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    path.write(contents)
    path
  end

  before do
    create_file('lib/services/order_service.rb', "class OrderService\nend\n")
    create_file('lib/services/legacy.rb', "# legacy\n\nVALUE = true\n")
  end

  it 'passes immutable FileInfo values to a positive custom predicate' do
    seen_files = []
    condition = lambda do |file|
      seen_files << file
      file.extension == '.rb' && file.lines_of_code <= 2
    end
    rule = ArchUnit.files(@project_root)
                   .in_folder('lib/services')
                   .should.adhere_to(condition, 'must be a short Ruby file')

    expect(rule).to be_a(ArchUnit::Checkable)
    expect(rule).to be_frozen
    expect(rule.check).to be_empty
    expect(seen_files.map(&:path)).to contain_exactly(
      'lib/services/legacy.rb', 'lib/services/order_service.rb'
    )
    expect(seen_files).to all(be_frozen)
  end

  it 'reports selected files that disagree with either mood' do
    positive = ArchUnit.files(@project_root)
                       .with_name('*_service.rb')
                       .should.adhere_to(
                         ->(file) { file.name.start_with?('legacy') }, 'must be legacy'
                       )
    negative = ArchUnit.files(@project_root)
                       .with_name('legacy.rb')
                       .should_not.adhere_to(
                         ->(file) { file.content.include?('legacy') }, 'legacy marker forbidden'
                       )

    expect(positive.check.map { |violation| violation.file_info.name }).to eq(['order_service'])
    expect(negative.check.map { |violation| violation.file_info.name }).to eq(['legacy'])
    expect(negative.check).to all(be_negated)
  end

  it 'returns a mood-aware empty-test violation unless explicitly allowed' do
    rule = ArchUnit.files(@project_root)
                   .in_folder('missing/**')
                   .should_not.adhere_to(->(_file) { true }, 'must not match')

    expect(rule.check).to contain_exactly(
      ArchUnit::EmptyTestViolation.new(filters: rule.subject_filters, is_negated: true)
    )
    expect(rule.check(ArchUnit::CheckOptions.new(allow_empty_tests: true))).to eq([])
  end

  it 'exposes custom predicates in both moods and rejects invalid arguments' do
    positive = ArchUnit.files(@project_root).should
    negative = ArchUnit.files(@project_root).should_not

    expect(positive).to respond_to(:adhere_to)
    expect(negative).to respond_to(:adhere_to)
    expect { positive.adhere_to(Object.new, 'message') }
      .to raise_error(ArgumentError, /callable/)
    expect { positive.adhere_to(->(_file) { true }, ' ') }
      .to raise_error(ArgumentError, /message/)
  end
end
