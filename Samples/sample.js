const ports = [8080, 9090, 9443];
const labels = {
  app: "quicklook-demo",
  env: "staging",
  enabled: true,
};

function describeEndpoint(port, index) {
  const protocol = port === 9443 ? "https" : "http";
  return `${index + 1}. ${protocol}://localhost:${port}/health`;
}

for (const [index, port] of ports.entries()) {
  console.log(describeEndpoint(port, index));
}

export async function fetchHealth(fetcher = fetch) {
  const response = await fetcher("/health", {
    headers: { "x-demo-app": labels.app },
  });
  if (!response.ok) throw new Error(`health failed: ${response.status}`);
  return response.json();
}
