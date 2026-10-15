# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe ArchUnit::Extraction::LoadPaths do
  around do |example|
    Dir.mktmpdir('archunit-load-paths') do |directory|
      @project_root = Pathname.new(directory).realpath
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

  def dependency(source, target)
    ArchUnit::Edge.new(
      source:, target:, external: false, import_kinds: [:require]
    )
  end

  it 'discovers sibling gem lib directories without evaluating gemspecs' do
    create_file('actionpack/actionpack.gemspec', "raise 'gemspec executed'\n")
    create_file('activesupport/activesupport.gemspec', "raise 'gemspec executed'\n")
    create_file('actionpack/lib/action_pack.rb', "require 'active_support'\n")
    create_file('activesupport/lib/active_support.rb')

    graph = ArchUnit::Extraction.extract_graph(@project_root)

    expect(graph).to include(
      dependency('actionpack/lib/action_pack.rb', 'activesupport/lib/active_support.rb')
    )
  end

  it 'uses normalized explicit load paths for non-standard component layouts' do
    create_file('lib/application.rb', "require 'billing/client'\n")
    create_file('components/billing/source/billing/client.rb')
    options = ArchUnit::CheckOptions.new(
      load_paths: ['components\\billing\\source']
    )

    graph = ArchUnit::Extraction.extract_graph(@project_root, options:)

    expect(graph).to include(
      dependency('lib/application.rb', 'components/billing/source/billing/client.rb')
    )
  end

  it 'preserves normal single-gem resolution without explicit options' do
    create_file('example.gemspec')
    create_file('lib/example.rb', "require 'example/support'\n")
    create_file('lib/example/support.rb')

    expect(ArchUnit::Extraction.extract_graph(@project_root)).to include(
      dependency('lib/example.rb', 'lib/example/support.rb')
    )
  end

  it 'rejects missing and out-of-project explicit load paths' do
    create_file('lib/example.rb')

    expect do
      ArchUnit::Extraction.extract_graph(
        @project_root,
        options: ArchUnit::CheckOptions.new(load_paths: ['missing/lib'])
      )
    end.to raise_error(ArchUnit::UserError, /existing directory/)

    Dir.mktmpdir('outside-archunit-project') do |outside|
      expect do
        ArchUnit::Extraction.extract_graph(
          @project_root,
          options: ArchUnit::CheckOptions.new(load_paths: [outside])
        )
      end.to raise_error(ArchUnit::UserError, /inside the project root/)
    end
  end

  it 'ignores discovered gem lib symlinks that leave the project root' do
    Dir.mktmpdir('outside-archunit-project') do |outside|
      create_file('components/escape/escape.gemspec')
      lib = @project_root.join('components/escape/lib')
      File.symlink(outside, lib)

      paths = described_class.resolve(@project_root)

      expect(paths).not_to include(Pathname.new(outside).realpath.to_s.tr('\\', '/'))
    end
  rescue NotImplementedError, Errno::EACCES
    skip 'creating symlinks is not available for this user or platform'
  end

  it 'includes normalized load-path options in the graph cache key' do
    create_file('lib/application.rb', "require 'billing/client'\n")
    create_file('components/billing/source/billing/client.rb')
    without_path = ArchUnit::Extraction.extract_graph(@project_root)
    first_options = ArchUnit::CheckOptions.new(
      load_paths: ['components/billing/source']
    )
    equivalent_options = ArchUnit::CheckOptions.new(
      load_paths: ['components\\billing\\source/']
    )
    with_path = ArchUnit::Extraction.extract_graph(@project_root, options: first_options)

    expect(with_path).not_to equal(without_path)
    expect(with_path).to include(
      dependency('lib/application.rb', 'components/billing/source/billing/client.rb')
    )
    expect(
      ArchUnit::Extraction.extract_graph(@project_root, options: equivalent_options)
    ).to equal(with_path)
  end
end
