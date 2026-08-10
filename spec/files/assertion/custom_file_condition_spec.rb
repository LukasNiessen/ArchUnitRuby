# frozen_string_literal: true

RSpec.describe ArchUnit::Files::Assertion, '.gather_custom_file_violations' do
  def file_info(path, lines_of_code: 1)
    extension = File.extname(path)
    ArchUnit::FileInfo.new(
      path:,
      name: File.basename(path, extension),
      extension:,
      directory: File.dirname(path),
      content: '# fixture',
      lines_of_code:
    )
  end

  it 'reports false results in the positive mood with user-provided context' do
    short = file_info('lib/short.rb', lines_of_code: 5)
    long = file_info('lib/long.rb', lines_of_code: 50)

    violations = described_class.gather_custom_file_violations(
      [short, long], ->(file) { file.lines_of_code < 10 }, 'file is too long',
      is_negated: false
    )

    expect(violations).to contain_exactly(
      ArchUnit::CustomFileViolation.new(file_info: long, message: 'file is too long')
    )
  end

  it 'reports true results in the negated mood through the same assertion path' do
    ruby_file = file_info('lib/source.rb')
    text_file = file_info('lib/notes.txt')

    violations = described_class.gather_custom_file_violations(
      [ruby_file, text_file], ->(file) { file.extension == '.rb' },
      'Ruby files are forbidden', is_negated: true
    )

    expect(violations).to contain_exactly(
      ArchUnit::CustomFileViolation.new(
        file_info: ruby_file, message: 'Ruby files are forbidden', is_negated: true
      )
    )
    expect(violations.first).to be_negated
  end

  it 'creates immutable value-comparable violation data' do
    info = file_info('lib/source.rb')
    violation = ArchUnit::CustomFileViolation.new(
      file_info: info, message: 'custom failure', is_negated: true
    )
    equal_value = ArchUnit::CustomFileViolation.new(
      file_info: info, message: 'custom failure', is_negated: true
    )

    expect(violation).to eq(equal_value)
    expect(violation.hash).to eq(equal_value.hash)
    expect(violation).to be_frozen
    expect(violation.message).to be_frozen
  end

  it 'requires a callable, a message, FileInfo inputs, a boolean mood, and boolean results' do
    info = file_info('lib/source.rb')

    expect do
      described_class.gather_custom_file_violations(
        [Object.new], ->(_file) { true }, 'message', is_negated: false
      )
    end.to raise_error(ArgumentError, /FileInfo/)
    expect do
      described_class.gather_custom_file_violations(
        [info], Object.new, 'message', is_negated: false
      )
    end.to raise_error(ArgumentError, /callable/)
    expect do
      described_class.gather_custom_file_violations(
        [info], ->(_file) { true }, ' ', is_negated: false
      )
    end.to raise_error(ArgumentError, /message/)
    expect do
      described_class.gather_custom_file_violations(
        [info], ->(_file) { true }, 'message', is_negated: nil
      )
    end.to raise_error(ArgumentError, /true or false/)
    expect do
      described_class.gather_custom_file_violations(
        [info], ->(_file) { :truthy }, 'message', is_negated: false
      )
    end.to raise_error(ArgumentError, /condition must return true or false/)
  end
end
