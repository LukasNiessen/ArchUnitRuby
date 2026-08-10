# frozen_string_literal: true

require 'tmpdir'

RSpec.describe ArchUnit::MetricExtraction do
  def write_source(root, relative_path, source)
    path = File.join(root, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, source)
    path
  end

  let(:source) do
    <<~RUBY
      # A comment is not a source line.
      require 'json'
      Kernel.require_relative 'helper'
      autoload :Thing, 'thing'
      Kernel.load 'legacy.rb'
      object.require 'ignored'

      def top_level_helper
        :ok
      end

      module Inventory
        def module_method
          :ignored_as_a_function
        end

        class Store
          attr_accessor :name
          attr_reader 'token'

          def initialize
            @name = 'Main'
            @token = nil
          end

          def display
            @name
          end

          def self.build
            new
          end
        end
      end

      class Inventory::Shelf
        def stock
          @count ||= 0
        end
      end

      =begin
      embedded comments are excluded from lines of code
      =end
    RUBY
  end

  it 'extracts Ruby file counts and symmetric class cohesion facts' do
    Dir.mktmpdir do |root|
      path = write_source(root, 'lib/inventory.rb', source)

      info = described_class.extract_file_info(path, relative_path: 'lib/inventory.rb')

      expect(info.lines_of_code).to eq(32)
      expect(info.statement_count).to be > 20
      expect(info.import_count).to eq(4)
      expect(info.class_count).to eq(2)
      expect(info.function_count).to eq(1)
      expect(info).to have_attributes(type_count: 3, abstract_type_count: 1)
      expect(info.class_infos.map(&:name)).to contain_exactly(
        'Inventory::Store', 'Inventory::Shelf'
      )

      store = info.class_infos.find { |class_info| class_info.name == 'Inventory::Store' }
      methods = store.methods.to_h { |method| [method.name, method] }
      fields = store.fields.to_h { |field| [field.name, field] }
      expect(methods.keys).to contain_exactly(
        'display', 'initialize', 'name', 'name=', 'self.build', 'token'
      )
      expect(methods.fetch('initialize').accessed_fields).to eq(%w[name token])
      expect(fields.fetch('name').accessed_by).to contain_exactly(
        'display', 'initialize', 'name', 'name='
      )
      expect(fields.fetch('token').accessed_by).to contain_exactly('initialize', 'token')
    end
  end

  it 'distinguishes Ruby abstractions from namespace-only modules' do
    abstraction_source = <<~RUBY
      module Namespace
        class Concrete
        end
      end

      module Contract
        def perform
          raise NotImplementedError
        end
      end

      module ModuleUtility
        def self.perform
          :done
        end
      end

      class AbstractBase
        def perform
          fail ::NotImplementedError, 'implement in a subclass'
        end
      end

      class Concrete
        def perform
          :done
        end
      end
    RUBY

    Dir.mktmpdir do |root|
      path = write_source(root, 'abstractions.rb', abstraction_source)
      info = described_class.extract_file_info(path)

      expect(info).to have_attributes(class_count: 3, type_count: 4, abstract_type_count: 2)
      expect(info.class_infos.map(&:name)).to contain_exactly(
        'Namespace::Concrete', 'AbstractBase', 'Concrete'
      )
    end
  end

  it 'extracts a located project in stable path order and honors exclusions' do
    Dir.mktmpdir do |root|
      write_source(root, 'lib/zeta.rb', "class Zeta\nend\n")
      write_source(root, 'lib/alpha.rb', "class Alpha\nend\n")
      write_source(root, 'generated/ignored.rb', "class Ignored\nend\n")

      project = described_class.extract_project_info(root, exclude_patterns: ['generated'])

      expect(project.files.map(&:path)).to eq(%w[lib/alpha.rb lib/zeta.rb])
      expect(project.classes.map(&:name)).to eq(%w[Alpha Zeta])
      expect(project.project_root).to eq(File.realpath(root).tr('\\', '/'))
    end
  end

  it 'returns physical code lines but no AST counts for malformed Ruby' do
    Dir.mktmpdir do |root|
      path = write_source(root, 'broken.rb', "class Broken\n  def nope(\nend\n")

      info = described_class.extract_file_info(path)

      expect(info.lines_of_code).to eq(3)
      expect([info.statement_count, info.class_count, info.function_count]).to eq([0, 0, 0])
      expect(info.class_infos).to be_empty
    end
  end

  it 'accepts path-like source files and validates missing paths' do
    Dir.mktmpdir do |root|
      path = Pathname.new(write_source(root, 'plain.rb', "def helper\nend\n"))
      expect(described_class.extract_file_info(path).function_count).to eq(1)
    end

    expect { described_class.extract_file_info(nil) }
      .to raise_error(ArgumentError, /non-empty path/)
    expect { described_class.extract_file_info('not-there.rb') }
      .to raise_error(ArgumentError, /existing file/)
  end
end
