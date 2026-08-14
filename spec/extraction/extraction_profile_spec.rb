# frozen_string_literal: true

RSpec.describe ArchUnit::Extraction::ExtractionProfile do
  it 'accumulates stage timings, counters, and cache state' do
    times = [1.0, 1.25, 2.0, 2.5]
    profile = described_class.new(clock: -> { times.shift })

    expect(profile.measure(:file_read) { :value }).to eq(:value)
    profile.measure(:file_read) { nil }
    profile.increment(:source_files, 3)
    profile.increment(:source_files)
    profile.record_cache_hit

    expect(profile).to be_cache_hit
    expect(profile.stage_seconds.fetch(:file_read)).to eq(0.75)
    expect(profile.counters.fetch(:source_files)).to eq(4)
    expect(profile.to_h).to include(
      cache_hit: true,
      stage_seconds: include(file_read: 0.75),
      counters: include(source_files: 4)
    )
  end

  it 'records elapsed time when the measured operation fails' do
    times = [4.0, 4.2]
    profile = described_class.new(clock: -> { times.shift })

    expect { profile.measure(:prism_parse) { raise 'broken' } }.to raise_error('broken')
    expect(profile.stage_seconds.fetch(:prism_parse)).to be_within(0.000_001).of(0.2)
  end

  it 'rejects invalid clocks, stages, counters, and amounts' do
    expect { described_class.new(clock: nil) }.to raise_error(ArgumentError, /clock/)

    profile = described_class.new
    expect { profile.measure(:unknown) { nil } }.to raise_error(ArgumentError, /stage/)
    expect { profile.increment(:unknown) }.to raise_error(ArgumentError, /counter/)
    expect { profile.increment(:imports, -1) }.to raise_error(ArgumentError, /amount/)
  end
end
