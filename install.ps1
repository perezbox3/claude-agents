$agentsDir = "$env:USERPROFILE\.claude\agents"
New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null

$sourceDir = "$PSScriptRoot\agents"
Get-ChildItem "$sourceDir\*.md" | ForEach-Object {
    Copy-Item $_.FullName "$agentsDir\$($_.Name)" -Force
    Write-Host "Installed: $($_.Name)"
}

Write-Host "`nDone. Agents installed to $agentsDir"
