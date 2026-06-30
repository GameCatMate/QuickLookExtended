import Foundation

struct Metric: Codable, Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let tags: [String: String]

    enum CodingKeys: String, CodingKey {
        case name, value, tags
    }
}

let metrics = [
    Metric(name: "latency.p95", value: 184.2, tags: ["env": "staging"]),
    Metric(name: "errors", value: 2, tags: ["service": "api"]),
]

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let data = try encoder.encode(metrics)
print(String(data: data, encoding: .utf8) ?? "[]")
