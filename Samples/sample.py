from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Iterable


@dataclass(frozen=True)
class Metric:
    name: str
    value: float
    tags: dict[str, str]


def render_table(metrics: Iterable[Metric]) -> str:
    rows = ["name                 value     tags"]
    rows.append("-" * 48)
    for metric in metrics:
        tag_text = ",".join(f"{k}={v}" for k, v in sorted(metric.tags.items()))
        rows.append(f"{metric.name:<20} {metric.value:>7.2f}   {tag_text}")
    return "\n".join(rows)


if __name__ == "__main__":
    now = datetime.now(timezone.utc).isoformat()
    sample = [
        Metric("latency.p95", 184.2, {"env": "staging", "time": now}),
        Metric("errors", 2, {"env": "staging", "service": "api"}),
        Metric("workers", 6, {"env": "staging", "service": "queue"}),
    ]
    print(render_table(sample))
