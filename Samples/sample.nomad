job "quicklook-demo" {
  datacenters = ["dc1"]
  type = "service"

  group "api" {
    count = 2

    network {
      port "http" { to = 8080 }
    }

    task "server" {
      driver = "docker"
      config {
        image = "ghcr.io/example/quicklook-demo:1.4.2"
        ports = ["http"]
      }
      env {
        LOG_LEVEL = "info"
      }
    }
  }
}
