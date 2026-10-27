# frozen_string_literal: true

require 'archunit/cli'
require 'open3'
require 'rbconfig'

RSpec.describe 'CLI packaging and subprocess acceptance' do
  let(:root) { File.expand_path('../..', __dir__) }

  it 'packages the executable and CLI implementation' do
    specification = Gem::Specification.load(File.join(root, 'archunit.gemspec'))

    expect(specification.bindir).to eq('exe')
    expect(specification.executables).to eq(['archunit'])
    expect(specification.files).to include('exe/archunit', 'lib/archunit/cli.rb')
  end

  it 'supports the full passing/failing/error flow in separate Ruby processes' do
    output, errors, status = Open3.capture3(
      RbConfig.ruby, File.join(root, 'scripts/check_cli.rb'), chdir: root
    )

    expect(status.exitstatus).to eq(0), "#{output}\n#{errors}"
    expect(errors).to eq('')
    expect(output).to include("CLI init/check/explain passed for archunit #{ArchUnit::VERSION}")
  end
end
