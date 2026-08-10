# frozen_string_literal: true

RSpec.describe ArchUnit::Testing::ColorUtils do
  def output(tty)
    Class.new do
      define_method(:initialize) { |value| @value = value }
      define_method(:tty?) { @value }
    end.new(tty)
  end

  it 'enables colour only for capable terminals without an override' do
    expect(described_class.supported?(output: output(true), environment: {})).to be(true)
    expect(described_class.supported?(output: output(false), environment: {})).to be(false)
    expect(described_class.supported?(output: Object.new, environment: {})).to be(false)
  end

  it 'respects NO_COLOR and dumb terminals' do
    expect(
      described_class.supported?(output: output(true), environment: { 'NO_COLOR' => '1' })
    ).to be(false)
    expect(
      described_class.supported?(output: output(true), environment: { 'TERM' => 'dumb' })
    ).to be(false)
  end

  it 'wraps every supported style with ANSI escapes when enabled' do
    methods = %i[red green yellow blue magenta cyan bold dim]

    methods.each do |method|
      expect(described_class.public_send(method, 'text', enabled: true)).to match(
        /\A\e\[\d+mtext\e\[0m\z/
      )
    end
  end

  it 'returns plain text when colour is disabled' do
    expect(described_class.red('plain', enabled: false)).to eq('plain')
  end

  it 'rejects invalid text and enabled flags' do
    expect { described_class.red(Object.new, enabled: true) }
      .to raise_error(ArgumentError, /text/)
    expect { described_class.red('text', enabled: nil) }
      .to raise_error(ArgumentError, /enabled/)
  end
end
