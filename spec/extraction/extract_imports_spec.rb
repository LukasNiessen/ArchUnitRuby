# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe ArchUnit::Extraction, '.extract_imports' do
  around do |example|
    Dir.mktmpdir('archunit-imports') do |directory|
      @project_root = Pathname.new(directory).realpath
      example.run
    end
  end

  def create_file(relative_path, contents = '# fixture')
    path = @project_root.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    path.write(contents)
    path
  end

  def extract(relative_path = 'lib/example.rb')
    described_class.extract_imports(
      @project_root.join(relative_path),
      project_root: @project_root
    )
  end

  it 'finds all supported literal dependency forms and their line numbers' do
    create_file('lib/example.rb', <<~RUBY)
      require 'json'
      Kernel.require('set')
      ::Kernel.require 'pathname'
      require_relative './support'
      autoload :Widget, 'widget'
      Namespace.autoload :Gadget, 'gadget'
      load 'scripts/boot.rb'
      Kernel.load('scripts/fallback.rb')
    RUBY
    create_file('lib/support.rb')

    expect(extract.map { |item| [item.module_name, item.import_kind, item.line_number] }).to eq(
      [
        ['json', :require, 1],
        ['set', :require, 2],
        ['pathname', :require, 3],
        ['./support', :require_relative, 4],
        ['widget', :autoload, 5],
        ['gadget', :autoload, 6],
        ['scripts/boot.rb', :load, 7],
        ['scripts/fallback.rb', :load, 8]
      ]
    )
  end

  it 'uses Ruby resolution rules for relative, project, standard-library, and load targets' do
    create_file('lib/example.rb', <<~RUBY)
      require_relative 'support'
      require 'sample/widget'
      require 'json'
      load 'scripts/boot.rake'
      require 'missing_archunit_dependency'
    RUBY
    create_file('lib/support.rb', "raise 'must not execute targets'\n")
    create_file('lib/sample/widget.rb')
    create_file('scripts/boot.rake')

    imports = extract.to_h { |item| [item.module_name, item] }

    expect(imports.fetch('support').resolved_path).to end_with('/lib/support.rb')
    expect(imports.fetch('sample/widget').resolved_path).to end_with('/lib/sample/widget.rb')
    expect(imports.fetch('json').resolved_path).to end_with('/json.rb')
    expect(imports.fetch('scripts/boot.rake').resolved_path).to end_with('/scripts/boot.rake')
    expect(imports.fetch('missing_archunit_dependency').resolved_path).to be_nil
  end

  it 'does not execute imported source while resolving it' do
    create_file('lib/example.rb', "require_relative 'explosive'\n")
    create_file('lib/explosive.rb', "raise 'executed'\n")

    expect { extract }.not_to raise_error
    expect(extract.first.resolved_path).to end_with('/lib/explosive.rb')
  end

  it 'ignores dynamic arguments, invalid arity, and custom require methods' do
    create_file('lib/example.rb', <<~'RUBY')
      name = 'json'
      require name
      require "#{name}"
      loader.require 'custom'
      autoload :Dynamic, name
      load
      require 'one', 'two'
    RUBY

    expect(extract).to be_empty
  end

  it 'ignores empty and null-byte dependency names without aborting the file' do
    create_file('lib/example.rb', <<~'RUBY')
      require ''
      require "\0"
      require 'json'
    RUBY

    expect(extract.map(&:module_name)).to eq(['json'])
  end

  it 'finds dependencies nested inside Ruby constructs' do
    create_file('lib/example.rb', <<~RUBY)
      module Example
        def self.load_dependency
          require_relative 'support'
        end
      end
    RUBY
    create_file('lib/support.rb')

    expect(extract.map(&:module_name)).to eq(['support'])
  end

  it 'ignores an import with an inline directive' do
    create_file('lib/example.rb', <<~RUBY)
      require 'json' # archunit: ignore
      require 'set'
    RUBY

    expect(extract.map(&:module_name)).to eq(['set'])
  end

  it 'applies a standalone directive to the immediately following line' do
    create_file('lib/example.rb', <<~RUBY)
      # archunit: ignore
      require 'json'
      require 'set'
    RUBY

    expect(extract.map(&:module_name)).to eq(['set'])
  end

  it 'supports directives scoped to exact modules and path prefixes' do
    create_file('lib/example.rb', <<~RUBY)
      require 'json' # archunit: ignore set
      require 'set' # archunit: ignore set
      require 'sample/plugin' # archunit: ignore sample, json
      require 'other/plugin' # archunit: ignore sample
    RUBY

    expect(extract.map(&:module_name)).to eq(%w[json other/plugin])
  end

  it 'can scope one directive across multiple imports on the same line' do
    create_file('lib/example.rb', <<~RUBY)
      require 'json'; require 'set' # archunit: ignore json
    RUBY

    expect(extract.map(&:module_name)).to eq(['set'])
  end

  it 'recognizes an inline directive anywhere within a multiline import call' do
    create_file('lib/example.rb', <<~RUBY)
      require(
        'json' # archunit: ignore
      )
      require 'set'
    RUBY

    expect(extract.map(&:module_name)).to eq(['set'])
  end

  it 'does not treat lookalike comments or separated standalone comments as directives' do
    create_file('lib/example.rb', <<~RUBY)
      require 'json' # archunit ignore
      # archunit: ignore

      require 'set'
    RUBY

    expect(extract.map(&:module_name)).to eq(%w[json set])
  end

  it 'skips a file that Prism cannot parse' do
    create_file('lib/example.rb', "require 'json'\ndef broken(\n")

    expect(extract).to eq([])
    expect(extract).to be_frozen
  end

  it 'returns immutable import collections and values' do
    create_file('lib/example.rb', "require 'json'\n")

    imports = extract

    expect(imports).to be_frozen
    expect(imports).to all(be_frozen)
  end

  it 'accepts String and Pathname inputs' do
    source = create_file('lib/example.rb', "require 'json'\n")

    imports = described_class.extract_imports(source.to_s, project_root: @project_root.to_s)

    expect(imports).not_to be_empty
  end

  it 'rejects missing or invalid input paths' do
    source = create_file('lib/example.rb')

    expect { described_class.extract_imports('', project_root: @project_root) }
      .to raise_error(ArchUnit::UserError, /source_file must be a non-empty path/)
    expect do
      described_class.extract_imports(
        @project_root.join('missing.rb'), project_root: @project_root
      )
    end
      .to raise_error(ArchUnit::UserError, /source_file must be an existing file/)
    expect { described_class.extract_imports(source, project_root: @project_root.join('missing')) }
      .to raise_error(ArchUnit::UserError, /project_root must be an existing directory/)
  end
end
