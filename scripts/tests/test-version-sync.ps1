# scripts/tests/test-version-sync.ps1
# Asserts that all four version-bearing locations agree.

param(
    [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
)

$ErrorActionPreference = 'Stop'

$marketplacePath = Join-Path $RepoRoot '.claude-plugin\marketplace.json'
$claudePluginPath = Join-Path $RepoRoot 'plugins\ehr-yearend-harness\.claude-plugin\plugin.json'
$codexPluginPath = Join-Path $RepoRoot 'plugins\ehr-yearend-harness\.codex-plugin\plugin.json'
$changelogPath = Join-Path $RepoRoot 'plugins\ehr-yearend-harness\CHANGELOG.md'

$marketplace = Get-Content -Raw -LiteralPath $marketplacePath | ConvertFrom-Json
$marketplaceVersion = ($marketplace.plugins | Where-Object { $_.name -eq 'ehr-yearend-harness' }).version

$claudePluginVersion = (Get-Content -Raw -LiteralPath $claudePluginPath | ConvertFrom-Json).version
$codexPluginVersion  = (Get-Content -Raw -LiteralPath $codexPluginPath  | ConvertFrom-Json).version

$changelog = Get-Content -Raw -LiteralPath $changelogPath
$changelogTopMatch = [regex]::Match($changelog, '(?m)^## \[(?<v>[^\]]+)\]')
$changelogTopVersion = if ($changelogTopMatch.Success) { $changelogTopMatch.Groups['v'].Value } else { $null }

$failed = 0
function Check {
    param([string]$Name, [string]$Actual, [string]$Expected)
    if ($Actual -ne $Expected) {
        Write-Host "FAIL: $Name = '$Actual' (expected '$Expected')"
        $script:failed++
    }
}

$expected = $claudePluginVersion
Check 'marketplace.json yearend entry version' $marketplaceVersion $expected
Check 'codex-plugin/plugin.json version'       $codexPluginVersion  $expected
Check 'CHANGELOG top version'                  $changelogTopVersion $expected

if ($failed -gt 0) {
    Write-Host "FAILED: $failed location(s) out of sync. Run scripts/bump-version.ps1 -To <version> to fix."
    exit 1
}

Write-Host "PASS: all 4 version locations agree on $expected"
