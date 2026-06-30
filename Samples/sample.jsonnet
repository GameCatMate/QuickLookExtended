local env = "staging";
local ports = [8080, 9090, 9443];

{
  apiVersion: "apps/v1",
  kind: "Deployment",
  metadata: {
    name: "quicklook-demo",
    labels: {
      environment: env,
      component: "api",
    },
  },
  spec: {
    replicas: 2,
    template: {
      spec: {
        containers: [
          {
            name: "api",
            image: "ghcr.io/example/quicklook-demo:1.4.2",
            ports: [{ containerPort: p } for p in ports],
          },
        ],
      },
    },
  },
}
