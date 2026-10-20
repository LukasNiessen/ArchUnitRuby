# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

RSpec.describe 'README quickstart' do
  around do |example|
    Dir.mktmpdir('archunit-readme-quickstart') do |directory|
      @project_root = directory
      File.write(File.join(directory, 'Gemfile'), '')
      write_file('app/database/order_repository.rb', "class OrderRepository; end\n")
      ArchUnit.clear_graph_cache
      example.run
      ArchUnit.clear_graph_cache
    end
  end

  def write_file(relative_path, content)
    path = File.join(@project_root, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def readme_rule
    ArchUnit.project_files
            .in_folder('app/api/**')
            .should_not.depend_on_files
            .in_folder('app/database/**')
  end

  it 'runs the documented first rule against files directly inside each folder' do
    write_file('app/api/orders.rb', "class Orders; end\n")

    Dir.chdir(@project_root) do
      expect(readme_rule).to pass
    end
  end

  it 'makes the documented first rule fail for a forbidden dependency' do
    write_file(
      'app/api/orders.rb',
      "require_relative '../database/order_repository'\nclass Orders; end\n"
    )

    Dir.chdir(@project_root) do
      expect(readme_rule.check).to contain_exactly(
        an_instance_of(ArchUnit::FileDependencyViolation)
      )
    end
  end
end
