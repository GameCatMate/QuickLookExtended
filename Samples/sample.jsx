import React, { useMemo, useState } from "react";

export function DashboardCard({ title, items }) {
  const [filter, setFilter] = useState("");
  const visible = useMemo(
    () => items.filter((item) => item.name.toLowerCase().includes(filter.toLowerCase())),
    [filter, items]
  );

  return (
    <section className="dashboard-card">
      <header>
        <h2>{title}</h2>
        <input value={filter} onChange={(event) => setFilter(event.target.value)} />
      </header>
      <ul>
        {visible.map((item) => (
          <li key={item.id} data-state={item.state}>
            <strong>{item.name}</strong>
            <span>{item.count}</span>
          </li>
        ))}
      </ul>
    </section>
  );
}
