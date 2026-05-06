[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$To,
    [string]$RepoRoot = "",
    [string]$Date = (Get-Date -Format "yyyy-MM-dd"),
    [switch]$DryRun
)

# scripts/bump-version.ps1
# Single-shot version bumper for ehr-yearend-harness.
# Updates the four places that hold the plugin version + opens a CHANGELOG entry.
#
# Usage:
#   scripts/bump-version.ps1 -To 0.5.0
#   scripts/bump-version.ps1 -To 0.5.0 -DryRun
#
# Files touched:
#   .claude-plugin/marketplace.json                                 (yearend entry .version)
#   plugins/ehr-yearend-harness/.claude-plugin/plugin.json          (.version)
#   plugins/ehr-yearend-harness/.codex-plugin/plugin.json           (.version)
#   plugins/ehr-yearend-harness/CHANGELOG.md                        (new "## [<To>] - <Date>" header inserted)

$ErrorActionPreference = "Stop"

if ($To -notmatch '^\d+\.\d+\.\d+(?:[-+][\w\.]+)?$') {
    throw "Version must be SemVer-like (e.g. 0.5.0 or 1.0.0-rc.1). Got: $To"
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $scriptDir = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($scriptDir)) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    $RepoRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
}

function Step { param([string]$m) Write-Host "[bump-version] $m" }

function Update-JsonVersion {
    param(
        [string]$Path,
        [string]$NewVersion,
        [scriptblock]$Locator
    )
    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing: $Path" }
    $raw = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
    $obj = $raw | ConvertFrom-Json
    & $Locator $obj $NewVersion
    if ($DryRun) {
        Step "(dry-run) would update $Path -> version=$NewVersion"
        return
    }
    $json = $obj | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    Step "Updated $Path -> $NewVersion"
}

# 1. .claude-plugin/marketplace.json — locate the yearend entry by name
Update-JsonVersion `
    -Path (Join-Path $RepoRoot ".claude-plugin\marketplace.json") `
    -NewVersion $To `
    -Locator {
        param($obj, $v)
        $entry = $obj.plugins | Where-Object { $_.name -eq 'ehr-yearend-harness' }
        if (-not $entry) { throw "ehr-yearend-harness entry not found in marketplace.json" }
        $entry.version = $v
    }

# 2. plugins/ehr-yearend-harness/.claude-plugin/plugin.json
Update-JsonVersion `
    -Path (Join-Path $RepoRoot "plugins\ehr-yearend-harness\.claude-plugin\plugin.json") `
    -NewVersion $To `
    -Locator { param($obj, $v) $obj.version = $v }

# 3. plugins/ehr-yearend-harness/.codex-plugin/plugin.json
Update-JsonVersion `
    -Path (Join-Path $RepoRoot "plugins\ehr-yearend-harness\.codex-plugin\plugin.json") `
    -NewVersion $To `
    -Locator { param($obj, $v) $obj.version = $v }

# 4. CHANGELOG — insert a new section after the intro paragraph
$changelogPath = Join-Path $RepoRoot "plugins\ehr-yearend-harness\CHANGELOG.md"
if (-not (Test-Path -LiteralPath $changelogPath)) { throw "Missing: $changelogPath" }
$cl = Get-Content -Raw -Encoding UTF8 -LiteralPath $changelogPath

if ($cl -match "(?m)^## \[$([regex]::Escape($To))\]") {
    Step "CHANGELOG already has [$To] section — skipping"
} else {
    $newEntry = @"
## [$To] - $Date

### Added
- _(채워주세요)_

### Changed
- _(채워주세요)_

---

"@
    # Insert before the first existing "## [" header. If none, append to end.
    $firstHeader = [regex]::Match($cl, "(?m)^## \[")
    if ($firstHeader.Success) {
        $newCl = $cl.Insert($firstHeader.Index, $newEntry)
    } else {
        $newCl = $cl.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $newEntry
    }
    if ($DryRun) {
        Step "(dry-run) would insert CHANGELOG section [$To] - $Date"
    } else {
        [System.IO.File]::WriteAllText($changelogPath, $newCl, [System.Text.UTF8Encoding]::new($false))
        Step "CHANGELOG: inserted [$To] - $Date (fill in details before commit)"
    }
}

Step "Done. Verify with scripts/tests/test-version-sync.ps1"
