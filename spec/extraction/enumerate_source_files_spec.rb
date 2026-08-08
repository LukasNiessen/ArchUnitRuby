# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe ArchUnit::Extraction, '.enumerate_source_files' do
  around do |example|
    Dir.mktmpdir('archunit-source-files') do |directory|
      @project_root = Pathname.new(directory).realpath
      example.run
    end
  end

  def create_file(relative_path, contents = '# fixture')
    path = @project_root.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    path.write(contents)
    path
  end

  it 'returns sorted, normalized, project-relative Ruby paths' do
    create_file('root.rb')
    create_file('lib/zeta.rb')
    create_file('lib/domain/alpha.rb')

    files = described_class.enumerate_source_files(@project_root)

    expect(files).to eq(['lib/domain/alpha.rb', 'lib/zeta.rb', 'root.rb'])
    expect(files).to be_frozen
    expect(files).to all(be_frozen)
  end

  it 'includes application, test, and specification Ruby sources' do
    create_file('app/service.rb')
    create_file('spec/service_spec.rb')
    create_file('test/service_test.rb')

    expect(described_class.enumerate_source_files(@project_root)).to contain_exactly(
      'app/service.rb',
      'spec/service_spec.rb',
      'test/service_test.rb'
    )
  end

  it 'excludes build output, dependencies, VCS metadata, and caches by directory name' do
    described_class::DEFAULT_EXCLUDED_DIRECTORIES.each do |directory|
      create_file("#{directory}/ignored.rb")
      create_file("nested/#{directory}/also_ignored.rb")
    end
    create_file('lib/included.rb')

    expect(described_class.enumerate_source_files(@project_root)).to eq(['lib/included.rb'])
  end

  it 'does not exclude source directories whose names only contain an excluded name' do
    create_file('lib/vendorized/client.rb')
    create_file('lib/tmp_source/generated.rb')
    create_file('lib/builders/report.rb')

    expect(described_class.enumerate_source_files(@project_root)).to contain_exactly(
      'lib/builders/report.rb',
      'lib/tmp_source/generated.rb',
      'lib/vendorized/client.rb'
    )
  end

  it 'ignores non-Ruby files and case-mismatched extensions' do
    create_file('lib/service.rb')
    create_file('lib/README.md')
    create_file('lib/native.so')
    create_file('lib/legacy.RB')

    expect(described_class.enumerate_source_files(@project_root)).to eq(['lib/service.rb'])
  end

  it 'returns an empty immutable list when a project has no Ruby files' do
    create_file('README.md')

    files = described_class.enumerate_source_files(@project_root)

    expect(files).to eq([])
    expect(files).to be_frozen
  end

  it 'accepts a string-like Pathname root' do
    create_file('lib/service.rb')

    expect(described_class.enumerate_source_files(@project_root)).to eq(['lib/service.rb'])
  end

  it 'rejects invalid roots as user errors' do
    file = create_file('not-a-directory.rb')

    expect { described_class.enumerate_source_files('') }
      .to raise_error(ArchUnit::UserError, 'project_root must be a non-empty path')
    expect { described_class.enumerate_source_files(@project_root.join('missing')) }
      .to raise_error(ArchUnit::UserError, 'project_root must be an existing directory')
    expect { described_class.enumerate_source_files(file) }
      .to raise_error(ArchUnit::UserError, 'project_root must be an existing directory')
  end

  it 'wraps filesystem failures as technical errors' do
    allow(Find).to receive(:find).and_raise(Errno::EACCES, @project_root.to_s)

    expect { described_class.enumerate_source_files(@project_root) }
      .to raise_error(ArchUnit::TechnicalError, /could not enumerate Ruby source files/)
  end

  it 'exposes a frozen default exclusion vocabulary' do
    expect(described_class::DEFAULT_EXCLUDED_DIRECTORIES).to include(
      '.git',
      '.bundle',
      'coverage',
      'pkg',
      'tmp',
      'vendor'
    )
    expect(described_class::DEFAULT_EXCLUDED_DIRECTORIES).to be_frozen
  end
end
