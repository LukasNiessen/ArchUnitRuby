# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe 'named layer policies' do
  around do |example|
    Dir.mktmpdir('archunit-layers') do |directory|
      @project_root = Pathname.new(directory).realpath
      @project_root.join('Gemfile').write('')
      create_file(
        'app/controllers/orders.rb',
        "require_relative '../services/orders'\nrequire_relative '../support/logger'\n"
      )
      create_file('app/services/orders.rb', "require_relative '../models/order'\n")
      create_file('app/models/order.rb')
      create_file('app/support/logger.rb')
      ArchUnit.clear_graph_cache
      example.run
      ArchUnit.clear_graph_cache
    end
  end

  def create_file(relative_path, contents = '# fixture')
    path = @project_root.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    path.write(contents)
  end

  def sample_layers
    ArchUnit.project_layers(@project_root)
            .layer('controllers').defined_by_folder('app/controllers')
            .layer('services').defined_by('app/services/**')
            .layer('models').defined_by_folder('app/models')
  end

  it 'checks a complete allowlist policy through the public fluent API' do
    rule = sample_layers
           .where_layer('controllers').may_only_depend_on_layers('services')
           .where_layer('services').may_only_depend_on_layers('models')
           .where_layer('models').may_only_depend_on_layers

    expect(rule).to be_a(ArchUnit::Checkable)
    expect(rule).to be_frozen
    expect(rule).to pass
  end

  it 'reports concrete evidence for disallowed allowlist dependencies' do
    rule = sample_layers
           .where_layer('controllers').may_only_depend_on_layers('models')

    expect(rule.check).to contain_exactly(
      have_attributes(
        source_layer: 'controllers', target_layer: 'services',
        rule: :may_only_depend_on_layers,
        dependency: have_attributes(
          source_label: 'app/controllers/orders.rb',
          target_label: 'app/services/orders.rb'
        )
      )
    )
  end

  it 'supports blocklists and gives them priority over allowlists' do
    rule = sample_layers
           .where_layer('services').may_only_depend_on_layers
           .where_layer('services').may_not_depend_on_layers('models')

    expect(rule.check).to contain_exactly(
      have_attributes(
        source_layer: 'services', target_layer: 'models',
        rule: :may_not_depend_on_layers
      )
    )
  end

  it 'ignores dependencies to files outside every declared layer' do
    rule = sample_layers
           .where_layer('controllers').may_only_depend_on_layers('services')

    expect(rule).to pass
  end

  it 'guards policy source layers that select no files' do
    rule = sample_layers
           .layer('missing').defined_by_folder('app/missing')
           .where_layer('missing').may_only_depend_on_layers

    expect(rule.check).to contain_exactly(be_a(ArchUnit::EmptyTestViolation))
    options = ArchUnit::CheckOptions.new(allow_empty_tests: true)
    expect(rule.check(options)).to be_empty
  end

  it 'keeps every fluent builder and branch immutable' do
    base = ArchUnit.layers(@project_root)
    definition_stage = base.layer('controllers')
    controllers = definition_stage.defined_by_folder('app/controllers')
    expanded = controllers.layer('controllers').defined_by('legacy/controllers/**')

    expect(base.layer_definitions).to be_empty
    expect(controllers.layer_definitions.one?).to be(true)
    expect(controllers.layer_definitions.first.filters.one?).to be(true)
    expect(expanded.layer_definitions.first.filters.length).to eq(2)
    expect(definition_stage).to be_frozen
  end

  it 'does no extraction while constructing a policy' do
    expect(ArchUnit::Extraction).not_to receive(:extract_graph)

    sample_layers.where_layer('models').may_only_depend_on_layers
  end

  it 'validates layer names, definitions, and dependency references early' do
    expect { ArchUnit.layers.layer('') }.to raise_error(ArgumentError, /layer name/)
    expect { ArchUnit.layers.where_layer('missing') }
      .to raise_error(ArgumentError, /must be defined/)
    expect { sample_layers.where_layer('controllers').may_only_depend_on_layers('missing') }
      .to raise_error(ArgumentError, /undefined target layer/)
    expect { sample_layers.where_layer('controllers').may_not_depend_on_layers }
      .to raise_error(ArgumentError, /at least one/)
  end

  it 'rejects malformed internal builder state defensively' do
    architecture_class = ArchUnit::Layers::FluentApi::LayeredArchitecture
    definition_builder = ArchUnit::Layers::FluentApi::LayerDefinitionBuilder
    dependency_builder = ArchUnit::Layers::FluentApi::LayerDependencyRuleBuilder
    definition = sample_layers.layer_definitions.first

    expect { architecture_class.new(project_locator: Object.new) }
      .to raise_error(ArgumentError, /project_locator/)
    expect { architecture_class.new(layer_definitions: [Object.new]) }
      .to raise_error(ArgumentError, /LayerDefinition/)
    expect { architecture_class.new(layer_definitions: [definition, definition]) }
      .to raise_error(ArgumentError, /unique/)
    expect { architecture_class.new(allowed_dependencies: Object.new) }
      .to raise_error(ArgumentError, /Hash/)
    expect { architecture_class.new(allowed_dependencies: { nil => [] }) }
      .to raise_error(ArgumentError, /layer name/)
    expect { definition_builder.new(Object.new, 'api') }
      .to raise_error(ArgumentError, /LayeredArchitecture/)
    expect { definition_builder.new(ArchUnit.layers, '') }
      .to raise_error(ArgumentError, /layer_name/)
    expect { dependency_builder.new(Object.new, 'api') }
      .to raise_error(ArgumentError, /LayeredArchitecture/)
    expect { dependency_builder.new(ArchUnit.layers, '') }
      .to raise_error(ArgumentError, /layer_name/)
  end

  it 'exposes project_layers and layers as equivalent public entry points' do
    expect(ArchUnit).to respond_to(:project_layers, :layers)
    expect(ArchUnit.method(:project_layers).arity).to eq(-1)
    expect(ArchUnit.layers(@project_root)).to be_a(
      ArchUnit::Layers::FluentApi::LayeredArchitecture
    )
  end
end
