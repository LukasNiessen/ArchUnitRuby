# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe ArchUnit::Extraction, 'constant dependencies' do
  let(:options) { ArchUnit::CheckOptions.new(dependency_analysis: :imports_and_constants) }

  around do |example|
    Dir.mktmpdir('archunit-constants') do |directory|
      @root = Pathname.new(directory).realpath
      described_class.clear_graph_cache
      example.run
      described_class.clear_graph_cache
    end
  end

  def source(path, contents)
    file = @root.join(path)
    FileUtils.mkdir_p(file.dirname)
    file.write(contents)
  end

  def dependencies(**keywords)
    described_class.extract_graph(@root, options:, **keywords).reject do |edge|
      edge.source == edge.target
    end
  end

  def targets(path = 'app/api/request.rb')
    dependencies.select { |edge| edge.source == path }.map(&:target)
  end

  it 'resolves the exact autoloaded application example without executing source' do
    source('app/api/request.rb', <<~RUBY)
      module Api
        class Request
          def call = Retrieval::Store.new
        end
      end
      raise 'source executed'
    RUBY
    source('app/retrieval/store.rb', 'module Retrieval; class Store; end; end')

    expect(targets).to eq(['app/retrieval/store.rb'])
    expect(dependencies.first.evidence).to contain_exactly(
      have_attributes(name: 'Retrieval::Store', line_number: 3, target_line_number: 1)
    )
    expect(described_class.extract_graph(@root).reject { |edge| edge.source == edge.target })
      .to be_empty
  end

  it 'distinguishes lexical nesting from a compact namespace and root qualification' do
    source('lib/outer.rb', 'module Outer; TOKEN = 1; end')
    source('lib/root.rb', 'TOKEN = 2')
    source('lib/nested.rb', 'module Outer; module Nested; TOKEN; end; end')
    source('lib/compact.rb', 'module Outer::Compact; TOKEN; ::TOKEN; Outer::TOKEN; end')

    expect(targets('lib/nested.rb')).to eq(['lib/outer.rb'])
    expect(targets('lib/compact.rb')).to eq(%w[lib/root.rb lib/outer.rb])
  end

  it 'does not fall back to another namespace when a nearer head shadows it' do
    source('lib/global.rb', 'module Store; class Item; end; end')
    source('lib/shadow.rb', 'module Api; module Store; end; end')
    source('app/api/request.rb', 'module Api; Store::Item; end')

    expect(targets).to be_empty
  end

  it 'resolves nested relative compact declarations using the known parent namespace' do
    source('lib/namespaces.rb', 'module Outer; module Inner; end; end')
    source('lib/item.rb', 'module Outer; class Inner::Item; end; end')
    source('app/api/request.rb', 'Outer::Inner::Item')

    expect(targets).to eq(['lib/item.rb'])
  end

  it 'records superclass and include, prepend, and extend references' do
    source('lib/base.rb', 'class Base; end')
    source('lib/mix.rb', 'module Mix; end')
    source('app/api/request.rb', <<~RUBY)
      class Request < ::Base
        include ::Mix
        prepend ::Mix
        extend ::Mix
      end
    RUBY

    expect(targets).to eq(%w[lib/base.rb lib/mix.rb])
    mix = dependencies.find { |edge| edge.target == 'lib/mix.rb' }
    expect(mix.evidence.map(&:line_number)).to eq([2, 3, 4])
  end

  it 'stabilizes dependent relative compact declarations before resolving references' do
    source('lib/namespaces.rb', 'module Outer; module Inner; module Deep; end; end; end')
    source('lib/namespace.rb', 'module Outer; module Inner::Deep; module Items; end; end; end')
    source('lib/item.rb', 'module Outer; module Inner::Deep; class Items::Item; end; end; end')
    source('app/api/request.rb', 'Outer::Inner::Deep::Items::Item')

    expect(targets).to eq(['lib/item.rb'])
  end

  it 'avoids guessed lexical ownership in singleton and dynamically changed namespaces' do
    source('lib/item.rb', 'class Item; end; module Store; class Item; end; end')
    source('app/api/request.rb', <<~RUBY)
      module Api
        const_set(:Store, build_store)
        Store::Item.new
        class << self
          Item = build_item
          Item.new
        end
      end
    RUBY

    expect(targets).to be_empty
  end

  it 'falls back to imports when dependent namespace owners exceed the bounded index passes' do
    source('lib/known.rb', 'class Known; end')
    declarations = ['module Root', 'module Branch; end']
    10.times { declarations.concat(['module Branch::Nested', 'module Branch; end']) }
    declarations << '::Known.new'
    declarations.concat(Array.new(11, 'end'))
    source('app/api/request.rb', declarations.join("\n"))
    profile = ArchUnit::Extraction::ExtractionProfile.new

    expect(dependencies(profile:)).to be_empty
    expect(profile.counters[:unresolved_constant_references]).to eq(1)
  end

  it 'resolves root-qualified writes and uses inside singleton bodies' do
    source('lib/item.rb', 'class ::Item; end; ::VALUE = 1')
    source('app/api/request.rb', 'class Request; class << self; ::Item.new; end; end; ::VALUE')

    expect(targets).to eq(['lib/item.rb'])
    expect(dependencies.first.evidence.map(&:name)).to eq(%w[::Item ::VALUE])
  end

  it 'does not guess inherited constants or substitute a colliding root constant' do
    source('lib/base.rb', 'class Base; TOKEN = 1; end')
    source('lib/root.rb', 'TOKEN = 2')
    source('app/api/request.rb', 'class Request < Base; TOKEN; end')

    expect(targets).to eq(['lib/base.rb'])
  end

  it 'ignores declaration names, comments, string text, and same-file uses' do
    source('lib/item.rb', 'class Item; end')
    source('app/api/request.rb', <<~RUBY)
      # Item.new
      text = 'Item.new'
      module Api
        class Local; end
        Local.new
      end
    RUBY

    expect(dependencies).to be_empty
  end

  it 'treats reopened definitions in different files as ambiguous, including local reopenings' do
    source('lib/one.rb', 'class Shared; end')
    source('lib/two.rb', 'class Shared; Shared.new; end')
    source('app/api/request.rb', 'Shared.new; Missing.new')
    profile = ArchUnit::Extraction::ExtractionProfile.new

    expect(dependencies(profile:)).to be_empty
    expect(profile.counters).to include(
      ambiguous_constant_references: 2, unresolved_constant_references: 1
    )
  end

  it 'models a constant alias as a definition with a dependency on its right hand side' do
    source('lib/item.rb', 'class Item; end')
    source('lib/alias.rb', 'Alias = Item')
    source('app/api/request.rb', 'Alias.new')

    expect(targets).to eq(['lib/alias.rb'])
    expect(targets('lib/alias.rb')).to eq(['lib/item.rb'])
  end

  it 'merges imports and uses into one edge while preserving both source locations' do
    source('lib/item.rb', 'class Item; end')
    source('app/api/request.rb', "require_relative '../../lib/item'\nItem.new\n")

    expect(dependencies).to contain_exactly(
      have_attributes(
        import_kinds: %i[require_relative constant_reference],
        evidence: contain_exactly(
          have_attributes(kind: :require_relative, line_number: 1),
          have_attributes(kind: :constant_reference, name: 'Item', line_number: 2)
        )
      )
    )
  end

  it 'shares cached indices across rules and refreshes changed definitions on clear_cache' do
    source('lib/item.rb', 'class Item; end')
    source('app/api/request.rb', 'Item.new')
    first = described_class.extract_graph(@root, options:)
    expect(described_class.extract_graph(@root, options:)).to equal(first)
    expect(described_class.extract_graph(@root)).not_to equal(first)
    source('lib/item.rb', 'class Renamed; end')
    expect(targets).to eq(['lib/item.rb'])

    refreshed = described_class.extract_graph(@root, options: options.with(clear_cache: true))
    expect(refreshed.reject { |edge| edge.source == edge.target }).to be_empty
  end

  it 'parses each source only once and reuses the graph on a repeated check' do
    source('lib/item.rb', 'class Item; end')
    source('app/api/request.rb', 'Item.new')
    expect(Prism).to receive(:parse).with(anything, filepath: anything).twice.and_call_original

    expect(targets).to eq(['lib/item.rb'])
    expect(targets).to eq(['lib/item.rb'])
  end

  it 'uses the same excluded source scope for definitions and references' do
    source('lib/item.rb', 'class Item; end')
    source('app/api/request.rb', 'Item.new')
    filtered = described_class.extract_graph(@root, options:, exclude_patterns: ['lib'])
    expect(filtered.reject { |edge| edge.source == edge.target }).to be_empty
  end
end
