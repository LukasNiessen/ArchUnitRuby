# frozen_string_literal: true

RSpec.describe 'file rule moods' do
  let(:scope) do
    ArchUnit.project_files('example')
            .in_folder('lib/**')
            .with_name('*.rb')
  end

  it 'creates a positive builder through the argument-less should mood' do
    mood = scope.should

    expect(mood).to be_a(
      ArchUnit::Files::FluentApi::PositiveMatchPatternFileConditionBuilder
    )
    expect(mood).to be_a(ArchUnit::Files::FluentApi::MatchPatternFileConditionBuilder)
    expect(mood.negated?).to be(false)
    expect(scope.method(:should).arity).to eq(0)
  end

  it 'creates a negated builder through the argument-less should_not mood' do
    mood = scope.should_not

    expect(mood).to be_a(
      ArchUnit::Files::FluentApi::NegatedMatchPatternFileConditionBuilder
    )
    expect(mood).to be_a(ArchUnit::Files::FluentApi::MatchPatternFileConditionBuilder)
    expect(mood.negated?).to be(true)
    expect(scope.method(:should_not).arity).to eq(0)
  end

  it 'threads identical immutable scope state into both moods' do
    positive = scope.should
    negative = scope.should_not

    expect(positive.project_locator).to eq('example')
    expect(positive.filters).to equal(scope.filters)
    expect(negative.filters).to equal(scope.filters)
    expect(positive).to be_frozen
    expect(negative).to be_frozen
  end

  it 'allows an unfiltered rule scope and leaves the source builder reusable' do
    base = ArchUnit.files

    expect(base.should.filters).to eq([])
    expect(base.should_not.filters).to eq([])
    expect(base.filters).to eq([])
  end

  it 'exposes exactly one mood stage with no selector or mood synonyms afterwards' do
    mood = scope.should
    builder_methods = mood.class.ancestors
                          .take_while { |ancestor| ancestor != Object }
                          .flat_map { |ancestor| ancestor.public_instance_methods(false) }

    expect(builder_methods).not_to include(
      :should, :should_not, :must, :must_not, :shouldnt,
      :with_name, :in_folder, :in_path, :in_file
    )
  end

  it 'rejects invalid shared mood state' do
    builder = ArchUnit::Files::FluentApi::MatchPatternFileConditionBuilder

    expect { builder.new(Object.new, negated: false) }
      .to raise_error(ArgumentError, /FileConditionBuilder/)
    expect { builder.new(scope, negated: nil) }
      .to raise_error(ArgumentError, /true or false/)
  end
end
