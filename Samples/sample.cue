package demo

#Service: {
    name:        string
    environment: "dev" | "staging" | "prod"
    replicas:    int & >=1 & <=10
    ports: [...int]
    labels: [string]: string
}

service: #Service & {
    name:        "quicklook-demo"
    environment: "staging"
    replicas:    2
    ports:       [8080, 9090, 9443]
    labels: {
        team: "platform"
        tier: "backend"
    }
}
