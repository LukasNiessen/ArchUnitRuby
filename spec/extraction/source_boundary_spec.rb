# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe 'Source discovery boundaries' do
  around do |example|
    Dir.mktmpdir('archunit-source-boundary') do |directory|
      @root = Pathname.new(directory).realpath
      @root.join('Gemfile').write('')
      @root.join('keep.rb').write('class Keep; end')
      ArchUnit.clear_graph_cache
      example.run
    ensure
      ArchUnit.clear_graph_cache
    end
  end

  it 'does not enumerate a symlinked file, including on hosts unable to create symlinks' do
    link = @root.join('linked.rb')
    link.write('class Linked; end')
    original = File.lstat(link)
    symlink_stat = original.dup
    allow(symlink_stat).to receive(:symlink?).and_return(true)
    allow(symlink_stat).to receive(:file?).and_return(false)
    allow(File).to receive(:lstat).and_call_original
    allow(File).to receive(:lstat).with(link.to_s).and_return(symlink_stat)

    expect(ArchUnit::Extraction.enumerate_source_files(@root)).to eq(['keep.rb'])
  end

  it 'checks the canonical boundary before a direct FileInfo read on every platform' do
    candidate = @root.join('keep.rb')
    outside = @root.parent.join('not-inside-project.rb')
    allow_any_instance_of(Pathname).to receive(:realpath).and_wrap_original do |method, *args|
      method.receiver == candidate ? outside : method.call(*args)
    end
    expect(File).not_to receive(:binread)

    expect { ArchUnit::Files::Extraction.extract_file_info(@root, 'keep.rb') }
      .to raise_error(ArchUnit::TechnicalError, /inside the project root/)
  end

  it 'treats paths on incompatible Windows volumes as outside, not as raw pathname errors' do
    allow_any_instance_of(Pathname).to receive(:relative_path_from).and_raise(ArgumentError)
    expect(File).not_to receive(:binread)

    expect { ArchUnit::Files::Extraction.extract_file_info(@root, 'keep.rb') }
      .to raise_error(ArchUnit::TechnicalError, /inside the project root/)
  end

  %i[inside outside dangling directory].each do |kind|
    it "skips #{kind} source links consistently in graphs and metrics" do
      Dir.mktmpdir('archunit-external-source') do |directory|
        outside = Pathname.new(directory)
        outside.join('secret.rb').write("raise 'must not read or execute'\nclass Secret; end")
        target = case kind
                 when :inside then @root.join('keep.rb')
                 when :outside then outside.join('secret.rb')
                 when :directory then outside
                 else outside.join('missing.rb')
                 end
        File.symlink(target, @root.join('linked.rb'))
        allow(File).to receive(:binread).and_call_original
        expect(File).not_to receive(:binread).with(@root.join('linked.rb'))

        graph = ArchUnit::Extraction.extract_graph(@root)
        metrics = ArchUnit::Metrics::Extraction.extract_project_info(@root)
        expect(graph.map(&:source)).to eq(['keep.rb'])
        expect(metrics.files.map(&:path)).to eq(['keep.rb'])
      end
    rescue NotImplementedError, Errno::EACCES
      skip 'creating symlinks is not available for this user or platform'
    end
  end
end
