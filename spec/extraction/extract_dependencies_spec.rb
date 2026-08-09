# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe ArchUnit::Extraction, '.extract_dependencies' do
  around do |example|
    Dir.mktmpdir('archunit-dependencies') do |directory|
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

  it 'emits project-relative internal edges and raw external targets' do
    create_file('lib/example.rb', <<~RUBY)
      require_relative 'support'
      require 'sample/widget'
      require 'json'
      require 'missing_archunit_dependency'
    RUBY
    create_file('lib/support.rb')
    create_file('lib/sample/widget.rb')

    edges = described_class.extract_dependencies(@project_root)

    expect(edges).to include(
      ArchUnit::Edge.new(
        source: 'lib/example.rb', target: 'lib/support.rb', external: false,
        import_kinds: [:require_relative]
      ),
      ArchUnit::Edge.new(
        source: 'lib/example.rb', target: 'lib/sample/widget.rb', external: false,
        import_kinds: [:require]
      ),
      ArchUnit::Edge.new(
        source: 'lib/example.rb', target: 'json', external: true, import_kinds: [:require]
      ),
      ArchUnit::Edge.new(
        source: 'lib/example.rb', target: 'missing_archunit_dependency', external: true,
        import_kinds: [:require]
      )
    )
  end

  it 'classifies all supported import kinds' do
    create_file('lib/example.rb', <<~RUBY)
      require_relative 'support'
      require 'sample/widget'
      autoload :Plugin, 'sample/plugin'
      load 'scripts/boot.rb'
    RUBY
    create_file('lib/support.rb')
    create_file('lib/sample/widget.rb')
    create_file('lib/sample/plugin.rb')
    create_file('scripts/boot.rb')

    import_kinds = described_class.extract_dependencies(@project_root).map(&:import_kinds)

    expect(import_kinds).to contain_exactly(
      [:require_relative], [:require], [:autoload], [:load]
    )
  end

  it 'keeps duplicate dependency calls as parallel edges for the graph assembly stage' do
    create_file('lib/example.rb', <<~RUBY)
      require_relative 'support'
      require_relative 'support'
    RUBY
    create_file('lib/support.rb')

    edges = described_class.extract_dependencies(@project_root)

    expect(edges.length).to eq(2)
    expect(edges.map(&:target)).to eq(['lib/support.rb', 'lib/support.rb'])
  end

  it 'does not mistake source under excluded dependency folders for project source' do
    create_file('lib/example.rb', "require 'vendor/dependency'\n")
    create_file('vendor/dependency.rb')

    expect(described_class.extract_dependencies(@project_root)).to contain_exactly(
      ArchUnit::Edge.new(
        source: 'lib/example.rb', target: 'vendor/dependency', external: true,
        import_kinds: [:require]
      )
    )
  end

  it 'skips malformed source files without losing dependencies from valid files' do
    create_file('lib/broken.rb', "require 'hidden'\ndef broken(\n")
    create_file('lib/valid.rb', "require_relative 'support'\n")
    create_file('lib/support.rb')

    sources = described_class.extract_dependencies(@project_root).map(&:source)

    expect(sources).to eq(['lib/valid.rb'])
  end

  it 'returns an immutable edge collection' do
    create_file('lib/example.rb', "require 'json'\n")

    edges = described_class.extract_dependencies(@project_root.to_s)

    expect(edges).to be_frozen
    expect(edges).to all(be_frozen)
  end
end
