[CmdletBinding()]
param(
    [string]$RepoRoot = "",
    [string]$ClaudeHome = (Join-Path $HOME ".claude"),
    [string]$CodexHome = (Join-Path $HOME ".codex"),
    [switch]$SkipClaude,
    [switch]$SkipCodex,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$MarketplaceName = "ehr-harness-yearend"
$PluginName = "ehr-yearend-harness"
$PluginKey = "$PluginName@$MarketplaceName"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $scriptDir = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($scriptDir)) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    $RepoRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
}

function Write-Step {
    param([string]$Message)
    Write-Host "[ehr-yearend] $Message"
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
        }
    }
}

function Read-JsonOrDefault {
    param(
        [string]$Path,
        [object]$DefaultValue
    )

    if (Test-Path -LiteralPath $Path) {
        $raw = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
        if ($raw.Trim().Length -gt 0) {
            return $raw | ConvertFrom-Json
        }
    }

    return $DefaultValue
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )

    $json = $Value | ConvertTo-Json -Depth 100
    if (-not $DryRun) {
        Ensure-Directory (Split-Path -Parent $Path)
        [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    }
}

function Set-ObjectProperty {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Value
    )

    if ($Object.PSObject.Properties.Name -contains $Name) {
        $Object.$Name = $Value
    } else {
        Add-Member -InputObject $Object -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Assert-PathUnder {
    param(
        [string]$Child,
        [string]$Parent
    )

    $childFull = [System.IO.Path]::GetFullPath($Child)
    $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $prefix = $parentFull + [System.IO.Path]::DirectorySeparatorChar

    if (-not ($childFull.Equals($parentFull, [System.StringComparison]::OrdinalIgnoreCase) -or $childFull.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Refusing to write outside expected root. Child='$childFull' Parent='$parentFull'"
    }
}

function Reset-Directory {
    param(
        [string]$Path,
        [string]$AllowedRoot
    )

    Assert-PathUnder -Child $Path -Parent $AllowedRoot
    if ($DryRun) {
        return
    }

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Copy-Directory {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$AllowedRoot
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        return
    }

    Reset-Directory -Path $Destination -AllowedRoot $AllowedRoot
    if (-not $DryRun) {
        Copy-Item -Path (Join-Path $Source "*") -Destination $Destination -Recurse -Force
    }
}

function Get-GitCommit {
    param([string]$Path)

    try {
        $sha = (& git -C $Path rev-parse HEAD 2>$null)
        if ($LASTEXITCODE -eq 0 -and $sha) {
            return ($sha | Select-Object -First 1).Trim()
        }
    } catch {
        return $null
    }

    return $null
}

function Get-GitRemote {
    param([string]$Path)

    try {
        $remote = (& git -C $Path config --get remote.origin.url 2>$null)
        if ($LASTEXITCODE -eq 0 -and $remote) {
            return ($remote | Select-Object -First 1).Trim()
        }
    } catch {
        return $null
    }

    return $null
}

function New-ClaudeMarketplaceSource {
    param([string]$RepoRoot)

    $remote = Get-GitRemote -Path $RepoRoot
    if ($remote) {
        return [pscustomobject]@{
            source = "git"
            url = $remote
        }
    }

    return [pscustomobject]@{
        source = "local"
        path = $RepoRoot
    }
}

function Get-PluginVersion {
    param([string]$RepoRoot)

    $manifestPath = Join-Path $RepoRoot "plugins\$PluginName\.claude-plugin\plugin.json"
    $manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
    return $manifest.version
}

function Assert-RepoShape {
    param([string]$RepoRoot)

    $required = @(
        ".claude-plugin\marketplace.json",
        ".agents\plugins\marketplace.json",
        "plugins\$PluginName\.claude-plugin\plugin.json",
        "plugins\$PluginName\.codex-plugin\plugin.json",
        "plugins\$PluginName\skills",
        "plugins\$PluginName\hooks",
        "plugins\$PluginName\references"
    )

    foreach ($relative in $required) {
        $path = Join-Path $RepoRoot $relative
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Missing required harness file or directory: $relative"
        }
    }
}

function Install-ClaudeHarness {
    param([string]$RepoRoot, [string]$ClaudeHome)

    Write-Step "Configuring Claude plugin marketplace and cache"

    $pluginsRoot = Join-Path $ClaudeHome "plugins"
    $cacheRoot = Join-Path $pluginsRoot "cache"
    $marketplaceInstallPath = $RepoRoot
    $version = Get-PluginVersion -RepoRoot $RepoRoot
    $cacheInstallPath = Join-Path $cacheRoot "$MarketplaceName\$PluginName\$version"
    $now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $source = New-ClaudeMarketplaceSource -RepoRoot $RepoRoot
    $gitSha = Get-GitCommit -Path $RepoRoot

    Ensure-Directory $pluginsRoot
    Ensure-Directory $cacheRoot

    Copy-Directory -Source (Join-Path $RepoRoot "plugins\$PluginName") -Destination $cacheInstallPath -AllowedRoot $cacheRoot

    $knownPath = Join-Path $pluginsRoot "known_marketplaces.json"
    $known = Read-JsonOrDefault -Path $knownPath -DefaultValue ([pscustomobject]@{})
    Set-ObjectProperty -Object $known -Name $MarketplaceName -Value ([pscustomobject]@{
        source = $source
        installLocation = $marketplaceInstallPath
        lastUpdated = $now
    })
    Write-JsonFile -Path $knownPath -Value $known

    $settingsPath = Join-Path $ClaudeHome "settings.json"
    $settings = Read-JsonOrDefault -Path $settingsPath -DefaultValue ([pscustomobject]@{})
    if (-not ($settings.PSObject.Properties.Name -contains "enabledPlugins")) {
        Set-ObjectProperty -Object $settings -Name "enabledPlugins" -Value ([pscustomobject]@{})
    }
    if (-not ($settings.PSObject.Properties.Name -contains "extraKnownMarketplaces")) {
        Set-ObjectProperty -Object $settings -Name "extraKnownMarketplaces" -Value ([pscustomobject]@{})
    }
    Set-ObjectProperty -Object $settings.enabledPlugins -Name $PluginKey -Value $true
    Set-ObjectProperty -Object $settings.extraKnownMarketplaces -Name $MarketplaceName -Value ([pscustomobject]@{
        source = $source
    })
    Write-JsonFile -Path $settingsPath -Value $settings

    $installedPath = Join-Path $pluginsRoot "installed_plugins.json"
    $installed = Read-JsonOrDefault -Path $installedPath -DefaultValue ([pscustomobject]@{
        version = 2
        plugins = [pscustomobject]@{}
    })
    if (-not ($installed.PSObject.Properties.Name -contains "version")) {
        Set-ObjectProperty -Object $installed -Name "version" -Value 2
    }
    if (-not ($installed.PSObject.Properties.Name -contains "plugins")) {
        Set-ObjectProperty -Object $installed -Name "plugins" -Value ([pscustomobject]@{})
    }

    $entry = [pscustomobject]@{
        scope = "user"
        installPath = $cacheInstallPath
        version = $version
        installedAt = $now
        lastUpdated = $now
    }
    if ($gitSha) {
        Set-ObjectProperty -Object $entry -Name "gitCommitSha" -Value $gitSha
    }
    Set-ObjectProperty -Object $installed.plugins -Name $PluginKey -Value @($entry)
    Write-JsonFile -Path $installedPath -Value $installed

    Write-Step "Claude ready: $PluginKey ($version)"
}

function Remove-TomlTable {
    param(
        [string]$Content,
        [string]$Header
    )

    $escapedHeader = [regex]::Escape($Header)
    return [regex]::Replace($Content, "(?ms)^$escapedHeader\s*\r?\n.*?(?=^\[|\z)", "")
}

function Set-TomlFeature {
    param(
        [string]$Content,
        [string]$Name,
        [bool]$Value
    )

    $valueText = if ($Value) { "true" } else { "false" }
    $featureLine = "$Name = $valueText"
    $match = [regex]::Match($Content, "(?ms)^\[features\]\s*\r?\n(?<body>.*?)(?=^\[|\z)")

    if (-not $match.Success) {
        $prefix = $Content.TrimEnd()
        if ($prefix.Length -gt 0) {
            $prefix += [Environment]::NewLine + [Environment]::NewLine
        }
        return $prefix + "[features]" + [Environment]::NewLine + $featureLine + [Environment]::NewLine
    }

    $block = $match.Value.TrimEnd()
    if ($block -match "(?m)^$([regex]::Escape($Name))\s*=") {
        $newBlock = [regex]::Replace($block, "(?m)^$([regex]::Escape($Name))\s*=.*$", $featureLine)
    } else {
        $newBlock = $block + [Environment]::NewLine + $featureLine
    }

    return $Content.Remove($match.Index, $match.Length).Insert($match.Index, $newBlock + [Environment]::NewLine)
}

function Install-CodexHarness {
    param([string]$RepoRoot, [string]$CodexHome)

    Write-Step "Configuring Codex marketplace, plugin, and hooks feature"

    Ensure-Directory $CodexHome
    $configPath = Join-Path $CodexHome "config.toml"
    $content = ""
    if (Test-Path -LiteralPath $configPath) {
        $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $configPath
        $backupPath = "$configPath.bak-ehr-yearend-$((Get-Date).ToString('yyyyMMddHHmmss'))"
        if (-not $DryRun) {
            Copy-Item -LiteralPath $configPath -Destination $backupPath -Force
        }
    }

    $content = Set-TomlFeature -Content $content -Name "codex_hooks" -Value $true
    $content = Remove-TomlTable -Content $content -Header "[marketplaces.$MarketplaceName]"
    $content = Remove-TomlTable -Content $content -Header "[plugins.`"$PluginKey`"]"

    $repoLiteral = $RepoRoot -replace "'", "''"
    $now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $append = @"
[marketplaces.$MarketplaceName]
last_updated = "$now"
source_type = "local"
source = '$repoLiteral'

[plugins."$PluginKey"]
enabled = true
"@

    $newContent = $content.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $append + [Environment]::NewLine
    if (-not $DryRun) {
        [System.IO.File]::WriteAllText($configPath, $newContent, [System.Text.UTF8Encoding]::new($false))
    }

    Write-Step "Codex ready: $PluginKey with codex_hooks = true"
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
Assert-RepoShape -RepoRoot $RepoRoot

Write-Step "Repo root: $RepoRoot"

if (-not $SkipClaude) {
    Install-ClaudeHarness -RepoRoot $RepoRoot -ClaudeHome $ClaudeHome
}

if (-not $SkipCodex) {
    Install-CodexHarness -RepoRoot $RepoRoot -CodexHome $CodexHome
}

Write-Step "Done. Restart Claude Code and Codex so both runtimes reload plugin metadata."
