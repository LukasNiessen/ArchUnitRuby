# frozen_string_literal: true

if ENV['COVERAGE'] == 'true'
  require 'simplecov'

  library_prefix = "#{File.expand_path('../lib', __dir__).tr('\\', '/')}/"
  SimpleCov.start do
    root File.expand_path('..', __dir__)
    enable_coverage :branch
    track_files 'lib/**/*.rb'
    add_filter { |source| !source.filename.tr('\\', '/').start_with?(library_prefix) }
    minimum_coverage line: 98, branch: 90
  end
end

require 'archunit'

RSpec.configure do |config|
  config.order = :random
  Kernel.srand config.seed
end
