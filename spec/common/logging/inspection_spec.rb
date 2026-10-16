# frozen_string_literal: true

require 'stringio'
require 'tmpdir'

RSpec.describe ArchUnit::Common::Logging::Inspection do
  def logger(output, level: :debug)
    ArchUnit::CheckLogger.new(ArchUnit::LoggingOptions.new(io: output, level:))
  end

  it 'restores nested contexts, including exceptions, and does not evaluate disabled details' do
    output = StringIO.new
    outer = logger(output)
    expect(described_class.logger).to be_nil
    described_class.debug { raise 'disabled' }
    described_class.with(outer) do
      expect do
        described_class.with(logger(StringIO.new, level: :info)) do
          described_class.debug { raise 'disabled' }
          raise 'check failed'
        end
      end.to raise_error('check failed')
      expect(described_class.logger).to equal(outer)
      described_class.debug { 'outer restored' }
    end
    expect(described_class.logger).to be_nil
    expect(output.string).to include('outer restored')
  end

  it 'isolates suspended fibers and threads from a running check' do
    first = StringIO.new
    second = StringIO.new
    fiber = Fiber.new do
      described_class.with(logger(first)) do
        Fiber.yield
        described_class.debug { 'first only' }
      end
    end
    fiber.resume
    described_class.with(logger(second)) do
      expect(Thread.new { described_class.logger }.value).to be_nil
      described_class.debug { 'second only' }
      fiber.resume
    end
    expect(first.string).to include('first only')
    expect(first.string).not_to include('second only')
    expect(second.string).to include('second only')
    expect(second.string).not_to include('first only')
  end

  it 'inspects a cached graph and selectors without changing rule results' do
    Dir.mktmpdir('archunit-inspection') do |root|
      File.write(File.join(root, 'Gemfile'), '')
      File.write(File.join(root, 'service.rb'), "require 'json'\nclass Service; end\n")
      rule = ArchUnit.project_files(root).should.have_name('*.rb')
      baseline = rule.check
      output = StringIO.new
      options = ArchUnit::CheckOptions.new(logging: ArchUnit::LoggingOptions.new(
        io: output, level: :debug
      ))
      expect(rule.check(options)).to eq(baseline)
      expect(output.string).to include(
        'project root:', 'discovered file: "service.rb"',
        'dependency: "service.rb" -> "json"', 'external=true',
        'selected file: "service.rb"', 'selected file count: 1', 'graph edges: 2'
      )
    ensure
      ArchUnit.clear_graph_cache
    end
  end

  it 'logs passing custom metric values once without repeating user callbacks' do
    Dir.mktmpdir('archunit-metric-inspection') do |root|
      File.write(File.join(root, 'Gemfile'), '')
      File.write(File.join(root, 'service.rb'), "class Service; def call; end; end\n")
      calls = []
      calculation = lambda do |subject|
        calls << subject.identifier
        7
      end
      rule = ArchUnit.metrics(root).custom_metric('score', 'fixture score', calculation)
                     .should_satisfy(->(value, _subject) { value == 7 })
      output = StringIO.new
      options = ArchUnit::CheckOptions.new(logging: ArchUnit::LoggingOptions.new(
        io: output, level: :debug
      ))
      expect(rule.check(options)).to be_empty
      expect(calls.length).to eq(1)
      expect(output.string).to include('metric file: "service.rb"', 'log metric: score=7')
      calls.clear
      expect(rule.check).to be_empty
      expect(calls.length).to eq(1)
    end
  end
end
