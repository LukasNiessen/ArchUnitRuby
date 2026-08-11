# frozen_string_literal: true

require 'pathname'
require 'stringio'

RSpec.describe ArchUnit::Common::Logging::LoggingOptions do
  it 'defaults to info output on stderr with file output disabled' do
    options = described_class.new

    expect(options).to have_attributes(
      level: :info, io: $stderr, output_directory: nil, append: false
    )
    expect(options.file_output?).to be(false)
    expect(options).to be_frozen
  end

  it 'normalizes idiomatic string levels and path-like output directories' do
    output = Pathname.new('tmp/logs')
    options = described_class.new(
      level: 'debug', io: nil, output_directory: output, append: true
    )

    expect(options).to have_attributes(
      level: :debug, io: nil, output_directory: File.expand_path(output), append: true
    )
    expect(options.file_output?).to be(true)
    expect(options.output_directory).to be_frozen
  end

  it 'accepts writable in-memory streams' do
    expect(described_class.new(io: StringIO.new).io).to be_a(StringIO)
  end

  it 'rejects unknown levels, sinks, paths, and append modes' do
    expect { described_class.new(level: :trace) }
      .to raise_error(ArgumentError, 'level must be one of: debug, info, warn, error')
    expect { described_class.new(io: Object.new) }
      .to raise_error(ArgumentError, 'io must respond to write or be nil')
    expect { described_class.new(output_directory: '') }
      .to raise_error(ArgumentError, /output_directory/)
    expect { described_class.new(append: nil) }
      .to raise_error(ArgumentError, 'append must be true or false')
  end
end
