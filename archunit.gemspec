# frozen_string_literal: true

require_relative 'lib/archunit/version'

Gem::Specification.new do |spec|
  spec.name = 'archunit'
  spec.version = ArchUnit::VERSION
  spec.authors = ['ArchUnitRuby contributors']

  spec.summary = 'Architecture testing for Ruby'
  spec.description = 'Define and enforce software architecture rules as ordinary Ruby tests.'
  spec.homepage = 'https://github.com/LukasNiessen/ArchUnitRuby'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.3'

  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*', 'README.md', 'LICENSE'].select { |path| File.file?(path) }
  spec.require_paths = ['lib']

  spec.add_dependency 'csv', '>= 3.3', '< 4.0'
  spec.add_dependency 'prism', '>= 1.0', '< 2.0'
end
