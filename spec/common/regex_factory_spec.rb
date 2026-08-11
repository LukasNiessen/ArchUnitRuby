# frozen_string_literal: true

RSpec.describe ArchUnit::Common::RegexFactory do
  def matches?(file_path, filter, class_name: nil)
    ArchUnit::Common::PatternMatching.matches_pattern?(file_path, filter, class_name:)
  end

  it 'builds filename matchers from glob strings' do
    matcher = described_class.filename_matcher('*_service.rb')

    expect(matcher).to be_a(ArchUnit::Common::Filter)
    expect(matcher.target).to eq(:filename)
    expect(matches?('lib/orders/order_service.rb', matcher)).to be(true)
    expect(matches?('lib/orders/order_repository.rb', matcher)).to be(false)
  end

  it 'builds folder matchers against the path without its filename' do
    matcher = described_class.folder_matcher('lib/**/service')

    expect(matcher.target).to eq(:path_without_filename)
    expect(matches?('lib/orders/service/order.rb', matcher)).to be(true)
    expect(matches?('lib/orders/repository/order.rb', matcher)).to be(false)
  end

  it 'builds path matchers with normalized separators' do
    matcher = described_class.path_matcher('lib\\**\\*.rb')

    expect(matcher.target).to eq(:path)
    expect(matches?('lib\\orders\\order.rb', matcher)).to be(true)
    expect(matches?('spec\\orders\\order_spec.rb', matcher)).to be(false)
  end

  it 'builds classname matchers' do
    matcher = described_class.classname_matcher('*Service')

    expect(matcher.target).to eq(:classname)
    expect(matches?('lib/order_service.rb', matcher, class_name: 'OrderService')).to be(true)
    expect(matches?('lib/order.rb', matcher, class_name: 'Order')).to be(false)
  end

  it 'excludes plain patterns using the parent selector context' do
    matcher = described_class.folder_matcher(
      'lib/**', except: ['index.rb', 'lib/generated/**']
    )

    expect(matches?('lib/orders/services/order.rb', matcher)).to be(true)
    expect(matches?('lib/orders/services/index.rb', matcher)).to be(false)
    expect(matches?('lib/generated/client.rb', matcher)).to be(false)
    expect(matcher.exclusions.map(&:target).uniq).to contain_exactly(
      :path, :path_without_filename, :filename
    )
  end

  it 'supports explicitly targeted exclusions' do
    matcher = described_class.path_matcher(
      'lib/**/*.rb',
      except: {
        in_path: 'lib/generated/**',
        in_folder: 'lib/testing',
        with_name: '*_spec.rb'
      }
    )

    expect(matches?('lib/orders/order.rb', matcher)).to be(true)
    expect(matches?('lib/generated/client.rb', matcher)).to be(false)
    expect(matches?('lib/testing/helper.rb', matcher)).to be(false)
    expect(matches?('lib/orders/order_spec.rb', matcher)).to be(false)
  end

  it 'excludes class names from class selectors' do
    matcher = described_class.classname_matcher('*Service', except: '*Legacy*')

    expect(matches?('lib/order_service.rb', matcher, class_name: 'OrderService')).to be(true)
    expect(matches?('lib/legacy.rb', matcher, class_name: 'LegacyOrderService')).to be(false)
  end

  it 'preserves user-supplied regular-expression behavior' do
    matcher = described_class.filename_matcher(/service/i)

    expect(matches?('lib/ORDER_SERVICE.rb', matcher)).to be(true)
    expect(matcher.regexp.options & Regexp::IGNORECASE).to eq(Regexp::IGNORECASE)
  end

  it 'builds exact file matchers that escape regex syntax' do
    matcher = described_class.exact_file_matcher('lib\\order[legacy].rb')

    expect(matcher.target).to eq(:path)
    expect(matcher.matching).to eq(:exact)
    expect(matches?('lib/order[legacy].rb', matcher)).to be(true)
    expect(matches?('lib/orderl.rb', matcher)).to be(false)
    expect(matches?('prefix/lib/order[legacy].rb', matcher)).to be(false)
  end

  it 'rejects unsupported patterns and empty exact paths' do
    expect { described_class.path_matcher(123) }
      .to raise_error(ArgumentError, 'pattern must be a String glob or Regexp')
    expect { described_class.exact_file_matcher('') }
      .to raise_error(ArgumentError, 'file_path must be a non-empty String')
    expect { described_class.path_matcher('lib/**', except: { beneath: 'vendor/**' }) }
      .to raise_error(ArgumentError, 'unknown targeted exclusion: :beneath')
    expect { described_class.path_matcher('lib/**', except: 123) }
      .to raise_error(ArgumentError, 'pattern must be a String glob or Regexp')
  end

  it 'is exposed from the gem public surface' do
    expect(ArchUnit::RegexFactory).to equal(described_class)
  end
end
