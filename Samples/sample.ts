type Metric = {
  name: string;
  value: number;
  tags: Record<string, string>;
};

const metrics: Metric[] = [
  { name: "latency.p95", value: 184.2, tags: { env: "staging" } },
  { name: "errors", value: 2, tags: { service: "api" } },
];

function formatMetric(metric: Metric): string {
  const tags = Object.entries(metric.tags).map(([key, value]) => `${key}=${value}`).join(",");
  return `${metric.name.padEnd(16)} ${metric.value.toFixed(2)} ${tags}`;
}

metrics.map(formatMetric).forEach((line) => console.log(line));
