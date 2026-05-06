# scripts/tests/test-install-all.ps1
# Regression test for install-all.ps1.
# Verifies that the installer:
#   1. Writes Claude marketplace + plugin enable + cache against a temp ClaudeHome
#   2. Writes Codex marketplace + plugin enable + codex_hooks feature against a temp CodexHome
#   3. Is idempotent (running twice produces the same effective state, no duplicate TOML blocks)
#   4. Preserves unrelated keys/blocks in pre-existing config files

param(
    [string]$InstallerPath = "$PSScriptRoot\..\install-all.ps1"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $InstallerPath)) {
    throw "InstallerPath does not exist: $InstallerPath"
}

$RepoRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
$MarketplaceName = 'ehr-harness-yearend'
$PluginName = 'ehr-yearend-harness'
$PluginKey = "$PluginName@$MarketplaceName"

$failed = 0
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        Write-Host "FAIL: $Message"
        $script:failed++
    }
}

function New-TempDir {
    $base = [System.IO.Path]::GetTempPath()
    $name = "ehr-yearend-test-" + [Guid]::NewGuid().ToString('N')
    $path = Join-Path $base $name
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Invoke-Installer {
    param(
        [string]$ClaudeHome,
        [string]$CodexHome
    )
    & powershell -NoProfile -ExecutionPolicy Bypass -File $InstallerPath `
        -RepoRoot $RepoRoot `
        -ClaudeHome $ClaudeHome `
        -CodexHome $CodexHome | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Installer exited non-zero: $LASTEXITCODE"
    }
}

$claudeHome = New-TempDir
$codexHome = New-TempDir

try {
    # Seed Codex config with an unrelated section to verify preservation.
    $codexConfig = Join-Path $codexHome 'config.toml'
    Set-Content -LiteralPath $codexConfig -Encoding UTF8 -Value @'
[unrelated]
keep_me = true
'@

    # ---- First run ----
    Invoke-Installer -ClaudeHome $claudeHome -CodexHome $codexHome

    # Claude assertions
    $settingsPath = Join-Path $claudeHome 'settings.json'
    Assert-True (Test-Path $settingsPath) "Claude settings.json should exist after install"
    $settings = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json
    Assert-True ($settings.enabledPlugins.$PluginKey -eq $true) "enabledPlugins[$PluginKey] should be true"
    Assert-True ($null -ne $settings.extraKnownMarketplaces.$MarketplaceName) "extraKnownMarketplaces should contain $MarketplaceName"

    $knownPath = Join-Path $claudeHome 'plugins\known_marketplaces.json'
    Assert-True (Test-Path $knownPath) "known_marketplaces.json should exist"
    $known = Get-Content -Raw -LiteralPath $knownPath | ConvertFrom-Json
    Assert-True ($null -ne $known.$MarketplaceName) "known_marketplaces should contain $MarketplaceName"

    $installedPath = Join-Path $claudeHome 'plugins\installed_plugins.json'
    Assert-True (Test-Path $installedPath) "installed_plugins.json should exist"
    $installed = Get-Content -Raw -LiteralPath $installedPath | ConvertFrom-Json
    Assert-True ($null -ne $installed.plugins.$PluginKey) "installed_plugins should contain $PluginKey"

    # Codex assertions
    Assert-True (Test-Path $codexConfig) "Codex config.toml should exist"
    $toml = Get-Content -Raw -LiteralPath $codexConfig
    Assert-True ($toml -match '(?m)^codex_hooks\s*=\s*true') "codex_hooks = true should be present"
    Assert-True ($toml -match "(?m)^\[marketplaces\.$([regex]::Escape($MarketplaceName))\]") "marketplaces.$MarketplaceName block should exist"
    Assert-True ($toml -match "\[plugins\.""$([regex]::Escape($PluginKey))""\]") "plugins.$PluginKey block should exist"
    Assert-True ($toml -match '(?m)^\[unrelated\]') "Pre-existing [unrelated] block should be preserved"
    Assert-True ($toml -match '(?m)^keep_me\s*=\s*true') "Pre-existing keep_me key should be preserved"

    # ---- Second run (idempotency) ----
    Invoke-Installer -ClaudeHome $claudeHome -CodexHome $codexHome

    $tomlAfter = Get-Content -Raw -LiteralPath $codexConfig

    $marketplaceCount = ([regex]::Matches($tomlAfter, "(?m)^\[marketplaces\.$([regex]::Escape($MarketplaceName))\]")).Count
    Assert-True ($marketplaceCount -eq 1) "marketplaces.$MarketplaceName should appear exactly once after re-run, got $marketplaceCount"

    $pluginCount = ([regex]::Matches($tomlAfter, "\[plugins\.""$([regex]::Escape($PluginKey))""\]")).Count
    Assert-True ($pluginCount -eq 1) "plugins.$PluginKey should appear exactly once after re-run, got $pluginCount"

    $hooksCount = ([regex]::Matches($tomlAfter, '(?m)^codex_hooks\s*=\s*true')).Count
    Assert-True ($hooksCount -eq 1) "codex_hooks = true should appear exactly once after re-run, got $hooksCount"

    Assert-True ($tomlAfter -match '(?m)^\[unrelated\]') "Re-run should still preserve [unrelated] block"

    $settingsAfter = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json
    Assert-True ($settingsAfter.enabledPlugins.$PluginKey -eq $true) "Re-run should keep enabledPlugins[$PluginKey] = true"
}
finally {
    Remove-Item -LiteralPath $claudeHome -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $codexHome -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failed -gt 0) {
    Write-Host "FAILED tests: $failed"
    exit 1
}

Write-Host "PASS: install-all.ps1 regression test OK"
