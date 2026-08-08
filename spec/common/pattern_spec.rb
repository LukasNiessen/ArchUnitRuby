# frozen_string_literal: true

RSpec.describe ArchUnit::Common::Pattern do
  def matches?(pattern, value)
    described_class.compile(pattern).match?(value)
  end

  it 'keeps regular expressions as regular expressions' do
    regexp = described_class.compile(/service/i)

    expect(regexp).to be_a(Regexp)
    expect(regexp).to be_frozen
    expect(regexp).to match('SERVICE')
  end

  it 'requires a glob string or regular expression' do
    expect { described_class.compile(123) }
      .to raise_error(ArgumentError, 'pattern must be a String glob or Regexp')
  end

  it 'keeps a single star within one path segment' do
    expect(matches?('*.rb', 'service.rb')).to be(true)
    expect(matches?('*.rb', 'lib/service.rb')).to be(false)
  end

  it 'lets a double star cross zero or more path segments' do
    expect(matches?('lib/**/*.rb', 'lib/service.rb')).to be(true)
    expect(matches?('lib/**/*.rb', 'lib/domain/service.rb')).to be(true)
    expect(matches?('lib/**/*.rb', 'app/service.rb')).to be(false)
  end

  it 'supports question marks and character classes within a segment' do
    expect(matches?('service?.[rR][bB]', 'service1.rb')).to be(true)
    expect(matches?('service?.[rR][bB]', 'service12.rb')).to be(false)
    expect(matches?('service[0-9].rb', 'service7.rb')).to be(true)
    expect(matches?('service[!0-9].rb', 'serviceA.rb')).to be(true)
    expect(matches?('service[!0-9].rb', 'service7.rb')).to be(false)
  end

  it 'treats an empty or unclosed character class as literal text' do
    expect(matches?('literal[].rb', 'literal[].rb')).to be(true)
    expect(matches?('literal[.rb', 'literal[.rb')).to be(true)
  end

  it 'normalizes separators and remains case-sensitive by default' do
    regexp = described_class.compile('lib\\**\\*.rb')

    expect(regexp).to match('lib/domain/service.rb')
    expect(regexp).not_to match('lib/domain/Service.RB')
  end
end
