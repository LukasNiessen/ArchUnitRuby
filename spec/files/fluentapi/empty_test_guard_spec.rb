# frozen_string_literal: true

require 'pathname'
require 'tmpdir'

RSpec.describe 'the empty-test guard across file terminals' do
  around do |example|
    Dir.mktmpdir('archunit-empty-guard') do |directory|
      @project_root = Pathname.new(directory).realpath
      @project_root.join('Gemfile').write('')
      @project_root.join('present.rb').write('# fixture')
      ArchUnit.clear_graph_cache
      example.run
      ArchUnit.clear_graph_cache
    end
  end

  def current_terminals
    missing = ArchUnit.files(@project_root).in_folder('missing/**')
    [
      missing.should.have_no_cycles,
      missing.should_not.have_name('*.rb'),
      missing.should.depend_on_files.in_folder('lib'),
      missing.should_not.depend_on_external_modules.matching('json'),
      missing.should.adhere_to(->(_file) { true }, 'must match')
    ]
  end

  it 'returns a mood-aware EmptyTestViolation from every current terminal type' do
    rules = current_terminals

    expect(rules.map(&:class)).to contain_exactly(
      ArchUnit::Files::FluentApi::CycleFreeFileCondition,
      ArchUnit::Files::FluentApi::MatchPatternFileCondition,
      ArchUnit::Files::FluentApi::DependOnFileCondition,
      ArchUnit::Files::FluentApi::DependOnExternalModuleCondition,
      ArchUnit::Files::FluentApi::CustomFileCondition
    )
    expect(rules.map { |rule| rule.check.fetch(0).class }).to all(eq(ArchUnit::EmptyTestViolation))
    expect(rules.map { |rule| rule.check.fetch(0).negated? }).to eq(
      [false, true, false, true, false]
    )
  end

  it 'allows empty selections consistently only through CheckOptions' do
    options = ArchUnit::CheckOptions.new(allow_empty_tests: true)

    expect(current_terminals.map { |rule| rule.check(options) }).to all(be_empty)
  end
end
