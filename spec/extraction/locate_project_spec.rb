# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe ArchUnit::Extraction, '.locate_project' do
  around do |example|
    Dir.mktmpdir('archunit-project-locator') do |directory|
      @temporary_root = Pathname.new(directory).realpath
      example.run
    end
  end

  def create_file(relative_path, contents = '')
    path = @temporary_root.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    path.write(contents)
    path
  end

  def normalized(path)
    path.realpath.to_s.tr('\\', '/')
  end

  it 'uses an explicit directory even when it has no project marker' do
    project = @temporary_root.join('explicit-project')
    project.mkdir

    expect(described_class.locate_project(project)).to eq(normalized(project))
  end

  it 'resolves a relative explicit directory from the working directory' do
    project = @temporary_root.join('projects/demo')
    FileUtils.mkdir_p(project)

    expect(
      described_class.locate_project('projects/demo', working_directory: @temporary_root)
    ).to eq(normalized(project))
  end

  it 'accepts Gemfile and gemspec files as explicit locators' do
    gemfile = create_file('gemfile-project/Gemfile')
    gemspec = create_file('gemspec-project/demo.gemspec')

    expect(described_class.locate_project(gemfile)).to eq(normalized(gemfile.dirname))
    expect(described_class.locate_project(gemspec)).to eq(normalized(gemspec.dirname))
  end

  it 'auto-detects the nearest ancestor containing a Gemfile' do
    project = create_file('project/Gemfile').dirname
    nested = project.join('lib/domain')
    FileUtils.mkdir_p(nested)

    expect(described_class.locate_project(working_directory: nested)).to eq(normalized(project))
  end

  it 'auto-detects the nearest ancestor containing a gemspec' do
    project = create_file('project/demo.gemspec').dirname
    nested = project.join('spec/integration')
    FileUtils.mkdir_p(nested)

    expect(described_class.locate_project(working_directory: nested)).to eq(normalized(project))
  end

  it 'prefers the nearest nested project marker' do
    create_file('outer/Gemfile')
    inner = create_file('outer/examples/inner/inner.gemspec').dirname
    nested = inner.join('lib')
    nested.mkdir

    expect(described_class.locate_project(working_directory: nested)).to eq(normalized(inner))
  end

  it 'falls back to the working directory when no marker exists' do
    working_directory = @temporary_root.join('unmarked/nested')
    FileUtils.mkdir_p(working_directory)

    expect(described_class.locate_project(working_directory:)).to eq(normalized(working_directory))
  end

  it 'rejects missing, empty, and unrelated explicit locators' do
    unrelated_file = create_file('README.md')

    expect { described_class.locate_project('', working_directory: @temporary_root) }
      .to raise_error(ArchUnit::UserError, 'locator must be a non-empty path')
    expect { described_class.locate_project('missing', working_directory: @temporary_root) }
      .to raise_error(
        ArchUnit::UserError,
        'project locator must be a directory, Gemfile, or .gemspec file'
      )
    expect { described_class.locate_project(unrelated_file) }
      .to raise_error(
        ArchUnit::UserError,
        'project locator must be a directory, Gemfile, or .gemspec file'
      )
  end

  it 'rejects a working directory that does not exist' do
    expect { described_class.locate_project(working_directory: @temporary_root.join('missing')) }
      .to raise_error(ArchUnit::UserError, 'working_directory must be an existing directory')
  end
end
