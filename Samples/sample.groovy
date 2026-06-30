class Metric {
    String name
    BigDecimal value
    Map<String, String> tags = [:]
}

def metrics = [
    new Metric(name: 'latency.p95', value: 184.2, tags: [env: 'staging']),
    new Metric(name: 'errors', value: 2, tags: [service: 'api']),
]

metrics.each { metric ->
    def tags = metric.tags.collect { key, value -> "$key=$value" }.join(',')
    println sprintf('%-16s %8.2f %s', metric.name, metric.value, tags)
}
