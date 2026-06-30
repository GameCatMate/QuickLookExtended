param(
    [string]$Environment = "staging",
    [int[]]$Ports = @(8080, 9090, 9443)
)

$ErrorActionPreference = "Stop"
$headers = @{ "X-Demo-App" = "quicklook-demo" }

foreach ($port in $Ports) {
    $uri = "http://127.0.0.1:$port/health"
    Write-Host "[$Environment] checking $uri"
    try {
        Invoke-RestMethod -Uri $uri -Headers $headers -TimeoutSec 2 | ConvertTo-Json -Depth 4
    } catch {
        Write-Warning $_.Exception.Message
    }
}
