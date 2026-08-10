# frozen_string_literal: true

require 'pathname'
require 'tmpdir'

RSpec.describe 'PlantUML slice diagrams' do
  def projected_edge(source, target, external: false)
    raw = ArchUnit::Edge.new(
      source: "lib/#{source}.rb", target: external ? target : "lib/#{target}.rb", external:
    )
    ArchUnit::ProjectedEdge.new(
      source_label: source, target_label: target, cumulated_edges: [raw]
    )
  end

  it 'parses declarations, both arrows, comments, directives, and implicit components' do
    diagram = ArchUnit::PlantUmlParser.parse(<<~PLANTUML)
      @startuml Architecture
      ' whole-line comment
      // another comment
      component [api] #Green
      component [services]
      [api] -> [services]
      [services] --> [models] ' inline comment
      [api] -> [services]
      skinparam componentStyle rectangle
      @enduml
    PLANTUML

    expect(diagram.components).to eq(%w[api services models])
    expect(diagram.dependencies).to eq(
      [
        ArchUnit::PlantUmlDependency.new(source: 'api', target: 'services'),
        ArchUnit::PlantUmlDependency.new(source: 'services', target: 'models')
      ]
    )
    expect(diagram).to be_frozen
    expect(diagram.components).to be_frozen
    expect(diagram.allows?('api', 'services')).to be(true)
    expect(diagram.allows?('models', 'api')).to be(false)
  end

  it 'renders isolated components and dependencies in stable sorted order' do
    edges = [projected_edge('services', 'models'), projected_edge('api', 'services')]

    expect(ArchUnit::PlantUmlRenderer.render(edges, components: ['orphan'])).to eq(<<~PLANTUML)
      @startuml
        component [api]
        component [models]
        component [orphan]
        component [services]
        [api] --> [services]
        [services] --> [models]
      @enduml
    PLANTUML
  end

  it 'exports byte-identical UTF-8 into a new parent directory' do
    edges = [projected_edge('api', 'services')]
    rendered = ArchUnit::PlantUmlRenderer.render(edges)

    Dir.mktmpdir('archunit-plantuml') do |directory|
      path = Pathname.new(directory).join('nested', 'architecture.puml')
      expect(ArchUnit::PlantUmlRenderer.export(edges, path)).to be_nil
      expect(path.binread.force_encoding(Encoding::UTF_8)).to eq(rendered)
    end
  end

  it 'validates parser, diagram, renderer, and component values' do
    expect { ArchUnit::PlantUmlParser.parse('') }.to raise_error(ArgumentError, /diagram text/)
    expect do
      ArchUnit::PlantUmlDiagram.new(dependencies: [Object.new])
    end.to raise_error(ArgumentError, /PlantUmlDependency/)
    expect do
      ArchUnit::PlantUmlDependency.new(source: '', target: 'services')
    end.to raise_error(ArgumentError, /source/)
    expect { ArchUnit::PlantUmlRenderer.render([Object.new]) }
      .to raise_error(ArgumentError, /ProjectedEdge/)
    expect { ArchUnit::PlantUmlRenderer.render([], components: ['bad]name']) }
      .to raise_error(ArgumentError, /component names/)
    expect { ArchUnit::PlantUmlRenderer.export([], '') }
      .to raise_error(ArgumentError, /output_path/)
  end
end
