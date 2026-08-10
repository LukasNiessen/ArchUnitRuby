# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe ArchUnit::Files::Extraction, '.extract_file_info' do
  around do |example|
    Dir.mktmpdir('archunit-file-info') do |directory|
      @project_root = Pathname.new(directory).realpath
      example.run
    end
  end

  def create_file(relative_path, contents)
    path = @project_root.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    path.binwrite(contents)
    path
  end

  it 'extracts normalized immutable source metadata and non-blank line count' do
    create_file(
      'lib/services/order_service.rb',
      "# frozen_string_literal: true\n\nclass OrderService\nend\n"
    )

    info = described_class.extract_file_info(
      @project_root, 'lib\\services\\order_service.rb'
    )

    expect(info).to have_attributes(
      path: 'lib/services/order_service.rb',
      name: 'order_service',
      extension: '.rb',
      directory: 'lib/services',
      lines_of_code: 3
    )
    expect(info.content).to include('class OrderService')
    expect(info).to be_frozen
    expect(info.path).to be_frozen
    expect(info.content).to be_frozen
  end

  it 'uses an empty directory for a project-root source file' do
    create_file('root.rb', "ROOT = true\n")

    expect(described_class.extract_file_info(@project_root, 'root.rb').directory).to eq('')
  end

  it 'scrubs invalid UTF-8 instead of aborting a project scan' do
    create_file('lib/legacy.rb', "value = \"\xFF\"\n".b)

    info = described_class.extract_file_info(@project_root, 'lib/legacy.rb')

    expect(info.content).to be_valid_encoding
    expect(info.lines_of_code).to eq(1)
  end

  it 'rejects missing, outside, and invalid source paths' do
    expect { described_class.extract_file_info(@project_root, '') }
      .to raise_error(ArgumentError, /relative_path/)
    expect { described_class.extract_file_info(@project_root, 'missing.rb') }
      .to raise_error(ArchUnit::TechnicalError, /does not exist/)
    expect { described_class.extract_file_info(@project_root, '../outside.rb') }
      .to raise_error(ArchUnit::TechnicalError, /inside the project root/)
    expect { described_class.extract_file_info('', 'lib/source.rb') }
      .to raise_error(ArgumentError, /project_root/)
  end

  it 'validates public FileInfo values' do
    attributes = {
      path: 'lib/source.rb', name: 'source', extension: '.rb', directory: 'lib',
      content: '', lines_of_code: 0
    }

    expect { ArchUnit::FileInfo.new(**attributes, path: '') }
      .to raise_error(ArgumentError, /path/)
    expect { ArchUnit::FileInfo.new(**attributes, name: '') }
      .to raise_error(ArgumentError, /name/)
    expect { ArchUnit::FileInfo.new(**attributes, lines_of_code: -1) }
      .to raise_error(ArgumentError, /non-negative/)
  end
end
