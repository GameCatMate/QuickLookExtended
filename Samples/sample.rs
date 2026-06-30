#[derive(Debug, Clone)]
struct Metric {
    name: String,
    value: f64,
    tags: Vec<(String, String)>,
}

impl Metric {
    fn new(name: &str, value: f64, tags: Vec<(&str, &str)>) -> Self {
        Self {
            name: name.to_string(),
            value,
            tags: tags.into_iter().map(|(k, v)| (k.to_string(), v.to_string())).collect(),
        }
    }

    fn render(&self) -> String {
        let tags = self.tags.iter().map(|(k, v)| format!("{k}={v}")).collect::<Vec<_>>().join(",");
        format!("{:<16} {:>8.2} {}", self.name, self.value, tags)
    }
}

fn main() {
    let metrics = vec![
        Metric::new("latency.p95", 184.2, vec![("env", "staging")]),
        Metric::new("errors", 2.0, vec![("service", "api")]),
    ];
    for metric in metrics {
        println!("{}", metric.render());
    }
}
