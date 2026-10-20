# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe ArchUnit::Extraction::ArchIgnore do
  around do |example|
    Dir.mktmpdir('archunit-archignore') do |directory|
      @root = Pathname.new(directory).realpath
      @root.join('Gemfile').write("raise 'never evaluate the project'\n")
      ArchUnit.clear_graph_cache
      example.run
    ensure
      ArchUnit.clear_graph_cache
    end
  end

  def create_file(path, content = '# fixture')
    target = @root.join(path)
    FileUtils.mkdir_p(target.dirname)
    target.binwrite(content)
    target
  end

  def sources(**options)
    ArchUnit::Extraction.enumerate_source_files(@root, **options)
  end

  it 'preserves default exclusions when absent or empty' do
    create_file('lib/source.rb')
    create_file('vendor/dependency.rb')
    expect(sources).to eq(['lib/source.rb'])
    create_file('.archignore', '')
    expect(sources).to eq(['lib/source.rb'])
  end

  it 'reads only the project-root file, not child configuration or Ruby expressions' do
    create_file('lib/.archignore', '*.rb')
    create_file('lib/child.rb')
    create_file('.archignore', "raise 'must not execute'\n")
    expect(sources).to eq(['lib/child.rb'])
  end

  {
    'files by basename' => ['skip.rb', 'lib/skip.rb', 'lib/keep.rb'],
    'directory basenames' => ['generated/', 'lib/generated/skip.rb', 'lib/keep.rb'],
    'plain directory names' => ['generated', 'lib/generated/skip.rb', 'lib/keep.rb'],
    'root-anchored directories' => ['/generated/', 'generated/skip.rb', 'nested/generated/keep.rb'],
    'root-anchored files' => ['/skip.rb', 'skip.rb', 'lib/skip.rb'],
    'path patterns' => ['app/generated/', 'app/generated/skip.rb', 'lib/generated/keep.rb'],
    'recursive globs' => ['**/*_generated.rb', 'app/skip_generated.rb', 'app/keep.rb'],
    'Windows separators' => ['app\\generated\\', 'app/generated/skip.rb', 'app/keep.rb'],
    'dot-prefix paths' => ['./app/generated/', 'app/generated/skip.rb', 'app/keep.rb'],
    'dot directories' => ['.generated/', 'app/.generated/skip.rb', 'app/.hidden/keep.rb']
  }.each do |description, (pattern, ignored, kept)|
    it "supports #{description}" do
      create_file(ignored)
      create_file(kept)
      create_file('.archignore', "  #{pattern}  \r\n")
      expect(sources).to eq([kept])
    end
  end

  it 'treats trailing slash as directory-only rather than excluding a similarly named file' do
    create_file('lib/keep.rb')
    create_file('.archignore', 'keep.rb/')
    expect(sources).to eq(['lib/keep.rb'])
  end

  it 'handles BOM, CRLF, comments, blanks, and malformed UTF-8 defensively' do
    create_file('app/source.rb')
    create_file('app/skip.rb')
    create_file('.archignore', "\xEF\xBB\xBF # comment\r\n\n\xFF\n skip.rb\r\n".b)
    expect(sources).to eq(['app/source.rb'])
  end

  it 'merges explicit exclusions without mutation and still applies repository policy to []' do
    create_file('vendor/dependency.rb')
    create_file('generated/skip.rb')
    create_file('lib/source.rb')
    create_file('.archignore', 'generated/')
    patterns = ['lib/'].freeze

    expect(sources).to eq(['lib/source.rb'])
    expect(sources(exclude_patterns: [])).to eq(['lib/source.rb', 'vendor/dependency.rb'])
    expect(sources(exclude_patterns: patterns)).to eq(['vendor/dependency.rb'])
    expect(patterns).to eq(['lib/'])
  end

  it 'keeps ignored files out of graph nodes, dependency targets, and file metrics' do
    create_file('app/api/request.rb', "require_relative '../database/store'\n")
    create_file('app/database/store.rb', 'module Database; class Store; end; end')
    create_file('.archignore', 'app/database/')
    graph = ArchUnit::Extraction.extract_graph(@root)

    expect(graph.map(&:source).uniq).to eq(['app/api/request.rb'])
    expect(graph.reject(&:external).map(&:target)).not_to include('app/database/store.rb')
    info = ArchUnit::Metrics::Extraction.extract_project_info(@root)
    expect(info.files.map(&:path)).to eq(['app/api/request.rb'])
    measurements = ArchUnit.metrics(@root).count.classes.measure
    expect(measurements.map { |item| item.subject.path }).to eq(['app/api/request.rb'])
  end

  it 'refreshes cache identity immediately on same-size edits, creation, and deletion' do
    create_file('first.rb')
    create_file('other.rb')
    original = ArchUnit::Extraction.extract_graph(@root)
    config = create_file('.archignore', 'first.rb')
    first = ArchUnit::Extraction.extract_graph(@root)
    config.binwrite('other.rb')
    other = ArchUnit::Extraction.extract_graph(@root)
    expect(first.map(&:source)).to eq(['other.rb'])
    expect(other.map(&:source)).to eq(['first.rb'])
    expect(other).not_to equal(first)
    expect(ArchUnit::Extraction.extract_graph(@root)).to equal(other)
    config.delete
    expect(ArchUnit::Extraction.extract_graph(@root)).to equal(original)
  end

  it 'reuses graph values for equivalent normalized patterns despite comment and order edits' do
    create_file('source.rb')
    config = create_file('.archignore', "skip.rb\nother.rb\n")
    graph = ArchUnit::Extraction.extract_graph(@root)
    config.binwrite("# changed\nother.rb\nskip.rb\nskip.rb\n\n")
    expect(ArchUnit::Extraction.extract_graph(@root)).to equal(graph)
  end

  it 'uses one configuration snapshot per graph extraction' do
    create_file('source.rb')
    create_file('.archignore', '# ignored comment')
    expect(described_class).to receive(:patterns).with(@root).once.and_call_original
    ArchUnit::Extraction.extract_graph(@root)
  end

  it 'accepts a 1 MiB file but rejects larger configuration with a user error' do
    create_file('.archignore', '#' * described_class::MAX_BYTES)
    expect(sources).to eq([])
    create_file('.archignore', '#' * (described_class::MAX_BYTES + 1))
    expect { sources }.to raise_error(ArchUnit::UserError, /1 MiB/)
  end

  ['!keep.rb', "bad\0name", '/'].each do |invalid|
    it "rejects unsupported configuration #{invalid.inspect}" do
      create_file('.archignore', invalid)
      expect { sources }.to raise_error(ArchUnit::UserError, /\.archignore/)
    end
  end

  it 'rejects directories masquerading as configuration files' do
    FileUtils.mkdir_p(@root.join('.archignore'))
    expect { sources }.to raise_error(ArchUnit::UserError, /regular file/)
  end

  %i[inside outside dangling].each do |target_kind|
    it "rejects #{target_kind} configuration symlinks without following them" do
      Dir.mktmpdir('archunit-outside-ignore') do |directory|
        target = case target_kind
                 when :inside then create_file('local-ignore', '*.rb')
                 when :outside
                   Pathname.new(directory).join('ignore').tap { |path| path.write('*.rb') }
                 else Pathname.new(directory).join('missing')
                 end
        File.symlink(target, @root.join('.archignore'))
        expect(File).not_to receive(:open)
        expect { sources }.to raise_error(ArchUnit::UserError, /symlink/)
      end
    rescue NotImplementedError, Errno::EACCES
      skip 'creating symlinks is not available for this user or platform'
    end
  end

  it 'turns a no-follow race into a user-facing error' do
    create_file('.archignore', 'skip.rb')
    allow(File).to receive(:open).and_raise(Errno::ELOOP)
    expect { sources }.to raise_error(ArchUnit::UserError, /symlink/)
  end

  it 'wraps configuration access failures as technical errors' do
    create_file('.archignore', 'skip.rb')
    allow(File).to receive(:open).and_raise(Errno::EACCES)
    expect { sources }.to raise_error(ArchUnit::TechnicalError, /could not read .archignore/)
  end

  it 'rejects a configuration replaced with a non-regular file before reading' do
    create_file('.archignore', 'skip.rb')
    handle = instance_double(File, stat: instance_double(File::Stat, file?: false))
    allow(File).to receive(:open).and_yield(handle)
    expect(handle).not_to receive(:read)
    expect { sources }.to raise_error(ArchUnit::UserError, /regular file/)
  end

  it 'wraps IO read failures as technical errors' do
    create_file('.archignore', 'skip.rb')
    allow(File).to receive(:open).and_raise(IOError, 'closed stream')
    expect { sources }.to raise_error(ArchUnit::TechnicalError, /closed stream/)
  end
end
