# frozen_string_literal: true

RSpec.describe ArchUnit::LCOMMetrics do
  def class_info(method_fields)
    methods = method_fields.map do |name, fields|
      ArchUnit::MetricMethodInfo.new(name: name.to_s, accessed_fields: fields.map(&:to_s))
    end
    fields = method_fields.values.flatten.uniq.map do |field_name|
      accessed_by = method_fields.filter_map do |method_name, accessed_fields|
        method_name.to_s if accessed_fields.include?(field_name)
      end
      ArchUnit::MetricFieldInfo.new(name: field_name.to_s, accessed_by:)
    end
    ArchUnit::ClassInfo.new(name: 'Example', file_path: 'example.rb', methods:, fields:)
  end

  def values_for(info)
    described_class::CALCULATIONS.to_h do |name, _calculation|
      [name, described_class.public_send(name).calculate(info)]
    end
  end

  it 'returns the canonical values for a partially cohesive class' do
    info = class_info(first: %i[a b], second: [:a], third: [:c])

    expect(values_for(info)).to include(
      lcom1: 1,
      lcom4: 2
    )
    expect(values_for(info).values_at(:lcom96a, :lcom3, :lcom5, :lcom_star))
      .to all(be_within(0.000_001).of(5.0 / 6.0))
    expect(values_for(info).values_at(:lcom96b, :lcom2))
      .to all(be_within(0.000_001).of(5.0 / 9.0))
  end

  it 'reports perfect cohesion when every method accesses every field' do
    info = class_info(first: %i[a b], second: %i[a b])

    expect(values_for(info)).to eq(
      lcom96a: 0.0, lcom96b: 0.0, lcom1: 0, lcom2: 0.0,
      lcom3: 0.0, lcom4: 1, lcom5: 0.0, lcom_star: 0.0
    )
  end

  it 'reports two components and maximum normalized distance for disjoint methods' do
    info = class_info(first: [:a], second: [:b])

    expect(values_for(info)).to eq(
      lcom96a: 1.0, lcom96b: 0.5, lcom1: 1, lcom2: 0.5,
      lcom3: 1.0, lcom4: 2, lcom5: 1.0, lcom_star: 1.0
    )
  end

  it 'uses transitive field sharing when finding LCOM4 components' do
    info = class_info(first: [:a], bridge: %i[a b], third: [:b])

    expect(described_class.lcom4.calculate(info)).to eq(1)
  end

  it 'defines empty and single-method edge cases without division errors' do
    empty = class_info({})
    one_method = class_info(only: [:field])
    two_methods_without_fields = class_info(first: [], second: [])

    expect(values_for(empty).values).to all(eq(0).or(eq(0.0)))
    expect(values_for(one_method)).to include(lcom4: 1)
    expect(values_for(one_method).except(:lcom4).values).to all(eq(0).or(eq(0.0)))
    expect(values_for(two_methods_without_fields)).to include(lcom1: 1, lcom4: 2)
    expect(values_for(two_methods_without_fields).except(:lcom1, :lcom4).values)
      .to all(eq(0.0))
  end

  it 'does not mutate the immutable extracted class information' do
    info = class_info(first: [:a], second: [:b])
    before = info.inspect

    described_class::CALCULATIONS.each_key do |name|
      described_class.public_send(name).calculate(info)
    end

    expect(info.inspect).to eq(before)
    expect(info).to be_frozen
  end
end
