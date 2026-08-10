# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe ArchUnit::Files::FluentApi::CycleFreeFileCondition do
  around do |example|
    Dir.mktmpdir('archunit-files-cycle') do |directory|
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

  it 'completes the first sentence-like file rule with no violations' do
    create_file('lib/a.rb', "require_relative 'b'\n")
    create_file('lib/b.rb')

    rule = ArchUnit.project_files(@project_root).should.have_no_cycles

    expect(rule).to be_a(ArchUnit::Checkable)
    expect(rule).to be_frozen
    expect(rule.check).to eq([])
  end

  it 'reports every cycle as a readable closed path' do
    create_file('lib/a.rb', "require_relative 'b'\n")
    create_file('lib/b.rb', "require_relative 'a'\n")

    violation = ArchUnit.files(@project_root).should.have_no_cycles.check.fetch(0)

    expect(violation).to be_a(ArchUnit::Files::Assertion::CycleViolation)
    expect(violation.path).to eq(['lib/a.rb', 'lib/b.rb', 'lib/a.rb'])
  end

  it 'checks only cycles wholly contained in the selected file scope' do
    create_file('lib/cyclic/a.rb', "require_relative 'b'\n")
    create_file('lib/cyclic/b.rb', "require_relative 'a'\n")
    isolated = create_file('lib/isolated.rb')

    rule = ArchUnit.project_files(@project_root).in_file('lib/isolated.rb')
                   .should.have_no_cycles

    expect(isolated).to be_file
    expect(rule.check).to eq([])
  end

  it 'returns an empty-test violation unless empty scopes are explicitly allowed' do
    create_file('lib/present.rb')
    rule = ArchUnit.project_files(@project_root).in_folder('missing/**')
                   .should.have_no_cycles

    expect(rule.check).to contain_exactly(
      ArchUnit::EmptyTestViolation.new(filters: rule.filters)
    )
    options = ArchUnit::CheckOptions.new(allow_empty_tests: true)
    expect(rule.check(options)).to eq([])
  end

  it 'is available in the positive mood only' do
    positive = ArchUnit.project_files(@project_root).should
    negative = ArchUnit.project_files(@project_root).should_not

    expect(positive).to respond_to(:have_no_cycles)
    expect(negative).not_to respond_to(:have_no_cycles)
  end
end
