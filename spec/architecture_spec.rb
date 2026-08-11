# frozen_string_literal: true

RSpec.describe 'ArchUnitRuby architecture' do
  let(:project_root) { File.expand_path('..', __dir__) }
  let(:domain_names) { %w[files graph layers metrics slices] }

  it 'keeps common independent from project code and limits its external toolchain' do
    internal_dependencies = ArchUnit.project_files(project_root)
                                    .in_path('lib/archunit/common/**/*.rb')
                                    .should.depend_on_files
                                    .in_path('lib/archunit/common/**/*.rb')
    external_dependencies = ArchUnit.project_files(project_root)
                                    .in_path('lib/archunit/common/**/*.rb')
                                    .should.depend_on_external_modules
                                    .matching(/\A(?:fileutils|prism|time)\z/)

    expect(internal_dependencies).to pass
    expect(external_dependencies).to pass
  end

  it 'prevents domain modules from depending on one another' do
    definitions = domain_names.reduce(ArchUnit.project_layers(project_root)) do |rule, name|
      rule.layer(name).defined_by("lib/archunit/#{name}/**/*.rb")
    end
    policy = domain_names.reduce(definitions) do |rule, name|
      rule.where_layer(name).may_not_depend_on_layers(*(domain_names - [name]))
    end

    expect(policy).to pass
  end

  it 'keeps every implementation file independent from the public surface' do
    rule = ArchUnit.project_files(project_root)
                   .in_path('lib/**/*.rb', except: 'lib/archunit.rb')
                   .should_not.depend_on_files
                   .in_path('lib/archunit.rb')

    expect(rule).to pass
  end

  it 'keeps the complete library dependency graph cycle-free' do
    rule = ArchUnit.project_files(project_root)
                   .in_path('lib/**/*.rb')
                   .should.have_no_cycles

    expect(rule).to pass
  end
end
