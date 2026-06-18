# install.ps1 - Deploy all agents to ~/.claude/agents/
# Deploys core-team (5 seats) and enterprise (5 seats).
# Called automatically by setup.ps1; run directly to update agents on an existing machine.

$ErrorActionPreference = "Continue"
$repoRoot = $PSScriptRoot
$agentsDir = "$env:USERPROFILE\.claude\agents"

New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null

$buckets = @("core-team", "enterprise")
$installed = 0

foreach ($bucket in $buckets) {
    $sourceDir = "$repoRoot\$bucket"
    if (-not (Test-Path $sourceDir)) {
        Write-Host "      [$bucket] folder not found - skipping" -ForegroundColor Yellow
        continue
    }
    Get-ChildItem "$sourceDir\*.md" | Where-Object { $_.Name -notmatch "^(README|INSTRUCTIONS)\.md$" } | ForEach-Object {
        Copy-Item $_.FullName "$agentsDir\$($_.Name)" -Force
        Write-Host "      Installed [$bucket]: $($_.Name)" -ForegroundColor Green
        $installed++
    }
}

Write-Host "`nDone. $installed agent(s) installed to $agentsDir"
