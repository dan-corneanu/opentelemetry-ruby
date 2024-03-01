# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'

describe OpenTelemetry::SDK::Metrics::Instrument::ObservableCounter do
  let(:metric_exporter) { OpenTelemetry::SDK::Metrics::Export::InMemoryMetricPullExporter.new }
  let(:meter) { OpenTelemetry.meter_provider.meter('test') }

  before do
    reset_metrics_sdk
    OpenTelemetry::SDK.configure
    OpenTelemetry.meter_provider.add_metric_reader(metric_exporter)
  end

  it 'counts without observe' do
    callback = Proc.new { 10 }
    meter.create_observable_counter('counter', unit: 'smidgen', description: 'a small amount of something', callback: callback)

    metric_exporter.pull
    last_snapshot = metric_exporter.metric_snapshots.last

    # puts "last_snapshot.inspect: #{last_snapshot.inspect}"
    _(last_snapshot[0].name).must_equal('counter')
    _(last_snapshot[0].unit).must_equal('smidgen')
    _(last_snapshot[0].description).must_equal('a small amount of something')
    _(last_snapshot[0].instrumentation_scope.name).must_equal('test')
    _(last_snapshot[0].data_points[0].value).must_equal(10)
    _(last_snapshot[0].data_points[0].attributes).must_equal({})
    _(last_snapshot[0].aggregation_temporality).must_equal(:delta)
  end

  it 'counts with observe' do
    callback = Proc.new { 10 }
    observable_counter = meter.create_observable_counter('counter', unit: 'smidgen', description: 'a small amount of something', callback: callback)
    observable_counter.observe(timeout: 10, attributes: {'foo' => 'bar'})

    metric_exporter.pull
    last_snapshot = metric_exporter.metric_snapshots.last

    _(last_snapshot[0].name).must_equal('counter')
    _(last_snapshot[0].unit).must_equal('smidgen')
    _(last_snapshot[0].description).must_equal('a small amount of something')
    _(last_snapshot[0].instrumentation_scope.name).must_equal('test')
    _(last_snapshot[0].data_points[0].value).must_equal(10)
    _(last_snapshot[0].data_points[0].attributes).must_equal('foo' => 'bar')

    _(last_snapshot[0].data_points[1].value).must_equal(10)
    _(last_snapshot[0].data_points[1].attributes).must_equal({})
    _(last_snapshot[0].aggregation_temporality).must_equal(:delta)
  end

  it 'counts with observe after initialization' do
    callback_1 = Proc.new { 10 }
    observable_counter = meter.create_observable_counter('counter', unit: 'smidgen', description: 'a small amount of something', callback: callback_1)
    _(observable_counter.instance_variable_get(:@callbacks).size).must_equal 1

    callback_2 = Proc.new { 20 }
    observable_counter.register_callback(callback_2)
    _(observable_counter.instance_variable_get(:@callbacks).size).must_equal 2

    metric_exporter.pull
    last_snapshot = metric_exporter.metric_snapshots.last

    _(last_snapshot[0].name).must_equal('counter')
    _(last_snapshot[0].unit).must_equal('smidgen')
    _(last_snapshot[0].description).must_equal('a small amount of something')
    _(last_snapshot[0].instrumentation_scope.name).must_equal('test')
    _(last_snapshot[0].data_points[0].value).must_equal(30)   # two callback aggregate value to 30
    _(last_snapshot[0].data_points[0].attributes).must_equal({})
  end

  it 'remove the callback after initialization result no metrics data' do
    callback_1 = Proc.new { 10 }
    observable_counter = meter.create_observable_counter('counter', unit: 'smidgen', description: 'a small amount of something', callback: callback_1)
    _(observable_counter.instance_variable_get(:@callbacks).size).must_equal 1

    observable_counter.unregister(callback_1)
    _(observable_counter.instance_variable_get(:@callbacks).size).must_equal 0

    metric_exporter.pull
    last_snapshot = metric_exporter.metric_snapshots.last

    _(last_snapshot[0].name).must_equal('counter')
    _(last_snapshot[0].unit).must_equal('smidgen')
    _(last_snapshot[0].description).must_equal('a small amount of something')
    _(last_snapshot[0].instrumentation_scope.name).must_equal('test')
    _(last_snapshot[0].data_points.size).must_equal 0
  end

end
