# frozen_string_literal: true

if ENV['COVERAGE'] == 'true'
  require 'simplecov'

  SimpleCov.start do
    enable_coverage :branch
    track_files 'lib/**/*.rb'
    minimum_coverage line: 98, branch: 90
  end
end

require 'archunit'

RSpec.configure do |config|
  config.order = :random
  Kernel.srand config.seed
end
