# frozen_string_literal: true

Metric = Struct.new(:name, :value, :tags, keyword_init: true)

metrics = [
  Metric.new(name: "latency.p95", value: 184.2, tags: { env: "staging" }),
  Metric.new(name: "errors", value: 2, tags: { env: "staging", service: "api" }),
  Metric.new(name: "workers", value: 6, tags: { env: "staging", service: "queue" })
]

metrics.each do |metric|
  tags = metric.tags.map { |key, value| "#{key}=#{value}" }.join(",")
  puts format("%-16s %8.2f %s", metric.name, metric.value, tags)
end
