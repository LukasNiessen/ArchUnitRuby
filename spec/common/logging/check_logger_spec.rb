# frozen_string_literal: true

require 'stringio'
require 'tmpdir'

RSpec.describe ArchUnit::Common::Logging::CheckLogger do
  let(:time) { Time.utc(2026, 8, 11, 10, 11, 12, 123_456) }
  let(:clock) { -> { time } }

  it 'does no work when logging is disabled' do
    logger = described_class.new(nil, clock: -> { raise 'clock should not run' })

    expect(logger.start_check('ExampleRule')).to be_nil
    expect(logger.log_path).to be_nil
    expect(logger.close).to be_nil
  end

  it 'uses the fixed event vocabulary and configured levels' do
    output = StringIO.new
    options = ArchUnit::LoggingOptions.new(level: :debug, io: output)
    logger = described_class.new(options, clock:)
    violation = Struct.new(:identifier).new('lib/example.rb')

    logger.start_check('ExampleRule')
    logger.log_progress('extracting graph')
    logger.log_violation(violation)
    logger.log_metric(name: :method_count, value: 7, subject: 'lib/example.rb:Example')
    logger.end_check('ExampleRule', violation_count: 1)

    expect(output.string).to include(
      '[INFO] start check: ExampleRule',
      '[INFO] log progress: extracting graph',
      '[WARN] log violation:',
      '[DEBUG] log metric: method_count=7 [lib/example.rb:Example]',
      '[INFO] end check: ExampleRule (1 violations)'
    )
  ensure
    logger&.close
  end

  it 'filters lower-priority events while retaining warnings and errors' do
    output = StringIO.new
    logger = described_class.new(ArchUnit::LoggingOptions.new(level: :warn, io: output), clock:)

    logger.start_check('ExampleRule')
    logger.log_progress('extracting graph')
    logger.log_metric(name: :classes, value: 3)
    logger.log_violation(Object.new)
    logger.end_check('ExampleRule', error: RuntimeError.new('boom'))

    expect(output.string).to include('[WARN] log violation:', '[ERROR] end check:')
    expect(output.string).not_to include('[INFO]', '[DEBUG]')
  ensure
    logger&.close
  end

  it 'creates timestamped files and honors overwrite and append modes' do
    Dir.mktmpdir('archunit-logging') do |root|
      directory = File.join(root, 'nested', 'logs')
      path = write_file_log(directory, append: false, message: 'first')

      expect(File.basename(path)).to eq('archunit-2026-08-11_10-11-12-123456.log')
      expect(File.read(path)).to include('log progress: first')

      write_file_log(directory, append: false, message: 'second')
      expect(File.read(path)).to include('log progress: second')
      expect(File.read(path)).not_to include('first')

      write_file_log(directory, append: true, message: 'third')
      expect(File.read(path)).to include('log progress: second', 'log progress: third')
    end
  end

  it 'validates logger inputs and event labels' do
    expect { described_class.new(Object.new) }
      .to raise_error(ArgumentError, /LoggingOptions/)
    expect { described_class.new(nil, clock: Object.new) }
      .to raise_error(ArgumentError, /clock/)

    logger = described_class.new(ArchUnit::LoggingOptions.new(io: StringIO.new), clock:)
    expect { logger.start_check('') }.to raise_error(ArgumentError, /check_name/)
    expect { logger.log_violation(nil) }.to raise_error(ArgumentError, /violation/)
    expect { logger.log_metric(name: '', value: 1) }.to raise_error(ArgumentError, /name/)
  ensure
    logger&.close
  end

  def write_file_log(directory, append:, message:)
    options = ArchUnit::LoggingOptions.new(
      level: :debug, io: nil, output_directory: directory, append:
    )
    logger = described_class.new(options, clock:)
    logger.log_progress(message)
    logger.close
    logger.log_path
  end
end
