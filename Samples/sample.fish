#!/usr/bin/env fish
set app_name quicklook-demo
set environment staging
set ports 8080 9090 9443

function log
    printf '[%s] %s\n' (date -u +%H:%M:%S) $argv
end

for port in $ports
    set url http://127.0.0.1:$port/health
    log checking $app_name $environment at $url
    curl --fail --silent --show-error --max-time 2 $url; or true
end
