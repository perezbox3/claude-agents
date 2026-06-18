# PowerShell Profile — Server Status on Shell Open
# Fill in your actual ipauth.net API keys before using.
# Auth keys  → ipauth.net dashboard > your server > "Auth Key"
# Query keys → ipauth.net dashboard > your server > "Query Key"

$servers = @(
    @{ Name = "development"; AuthUrl = "https://ipauth.net/whitelist/?key=YOUR_DEV_AUTH_KEY";      ServerUrl = "https://ipauth.net/serverquery/?key=YOUR_DEV_QUERY_KEY" },
    @{ Name = "dhfc";        AuthUrl = "https://ipauth.net/whitelist/?key=YOUR_DHFC_AUTH_KEY";     ServerUrl = "https://ipauth.net/serverquery/?key=YOUR_DHFC_QUERY_KEY" },
    @{ Name = "projects";    AuthUrl = "https://ipauth.net/whitelist/?key=YOUR_PROJECTS_AUTH_KEY"; ServerUrl = "https://ipauth.net/serverquery/?key=YOUR_PROJECTS_QUERY_KEY" },
    @{ Name = "personal";    AuthUrl = "https://ipauth.net/whitelist/?key=YOUR_PERSONAL_AUTH_KEY"; ServerUrl = "https://ipauth.net/serverquery/?key=YOUR_PERSONAL_QUERY_KEY" }
)

$jobs = $servers | ForEach-Object {
    $job = Start-Job -ScriptBlock {
        param($authUrl, $serverUrl)
        try { Invoke-RestMethod $authUrl -TimeoutSec 5 | Out-Null } catch {}
        try {
            $response = Invoke-RestMethod $serverUrl -TimeoutSec 5
            if ($response -match 'status:success') { "Available" } else { "Unavailable" }
        } catch { "Unavailable" }
    } -ArgumentList $_.AuthUrl, $_.ServerUrl
    @{ Name = $_.Name; Job = $job }
}

$results = $jobs | ForEach-Object {
    $status = Receive-Job $_.Job -Wait
    Remove-Job $_.Job
    @{ Name = $_.Name; Status = $status }
}

for ($i = 0; $i -lt $results.Count; $i++) {
    $color = if ($results[$i].Status -eq "Available") { "Green" } else { "Red" }
    Write-Host -NoNewline "$($results[$i].Name): "
    Write-Host -NoNewline $results[$i].Status -ForegroundColor $color
    if ($i -lt $results.Count - 1) { Write-Host -NoNewline "  |  " }
}
Write-Host ""
