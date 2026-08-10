# frozen_string_literal: true

require 'tmpdir'

RSpec.describe ArchUnit::MetricExtraction do
  def write_source(root, relative_path, source)
    path = File.join(root, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, source)
  end

  it 'derives distinct internal afferent and efferent coupling from the real graph' do
    Dir.mktmpdir do |root|
      write_source(root, 'a.rb', "class A\nend\n")
      write_source(root, 'b.rb', "require_relative 'a'\nclass B\nend\n")
      write_source(
        root, 'c.rb',
        "require 'json'\nrequire_relative 'a'\nrequire_relative 'b'\nclass C\nend\n"
      )

      infos = described_class.extract_distance_infos(
        root, options: ArchUnit::CheckOptions.new(clear_cache: true)
      ).to_h { |info| [info.path, info] }

      expect(infos.fetch('a.rb')).to have_attributes(
        afferent_coupling: 2, efferent_coupling: 0, project_file_count: 3
      )
      expect(infos.fetch('b.rb')).to have_attributes(
        afferent_coupling: 1, efferent_coupling: 1
      )
      expect(infos.fetch('c.rb')).to have_attributes(
        afferent_coupling: 0, efferent_coupling: 2
      )
    end
  end

  it 'returns an empty immutable result for a project without Ruby sources' do
    Dir.mktmpdir do |root|
      infos = described_class.extract_distance_infos(root)

      expect(infos).to eq([])
      expect(infos).to be_frozen
    end
  end
end
