import React from "react";

type Metric = {
  id: string;
  name: string;
  value: number;
  state: "ok" | "warn" | "error";
};

export function MetricList({ metrics }: { metrics: Metric[] }) {
  return (
    <ul className="metric-list">
      {metrics.map((metric) => (
        <li key={metric.id} data-state={metric.state}>
          <span>{metric.name}</span>
          <strong>{metric.value.toFixed(2)}</strong>
        </li>
      ))}
    </ul>
  );
}
