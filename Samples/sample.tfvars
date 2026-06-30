environment = "staging"
replicas    = 2
ports       = [8080, 9090, 9443]
enabled     = true
labels = {
  team = "platform"
  tier = "backend"
}
