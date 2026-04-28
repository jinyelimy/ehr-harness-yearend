<#
.SYNOPSIS
    Yearend Harness source to target .claude/ sync (for environments where junctions don't work).

.DESCRIPTION
    Copy all items from plugins/ehr-yearend-harness/skills/* and agents/*.md to target .claude/skills/ and .claude/agents/.
    Similar to robocopy /MIR, files in target are removed if they don't exist in source.

.PARAMETER SourceRoot
    Absolute path to plugins/ehr-yearend-harness (parent directory of SKILLs).
    Note: Task 9 test calls this with skills/ and agents/ directly under $srcRoot.

.PARAMETER TargetClaudeDir
    Absolute path to target project's .claude directory.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SourceRoot,

    [Parameter(Mandatory=$true)]
    [string]$TargetClaudeDir
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $SourceRoot)) {
    throw "SourceRoot does not exist: $SourceRoot"
}

$targetSkills = Join-Path $TargetClaudeDir "skills"
$targetAgents = Join-Path $TargetClaudeDir "agents"
New-Item -ItemType Directory -Force -Path $targetSkills | Out-Null
New-Item -ItemType Directory -Force -Path $targetAgents | Out-Null

# Sync skills/ - target only yearend- prefix
$skillsSrc = Join-Path $SourceRoot "skills"
if (Test-Path $skillsSrc) {
    # First remove target yearend-* skills not in source
    $targetSkillItems = @(Get-ChildItem -Directory $targetSkills -ErrorAction SilentlyContinue)
    foreach ($item in $targetSkillItems) {
        if ($item.Name -like "yearend-*") {
            $srcDir = Join-Path $skillsSrc $item.Name
            if (-not (Test-Path $srcDir)) {
                Write-Host "REMOVE: $($item.FullName)"
                Remove-Item -Recurse -Force $item.FullName
            }
        }
    }

    # Copy from source to target (overwrite)
    $srcSkillItems = @(Get-ChildItem -Directory $skillsSrc)
    foreach ($item in $srcSkillItems) {
        $dest = Join-Path $targetSkills $item.Name
        if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
        Copy-Item -Recurse $item.FullName $dest
        Write-Host "COPY : skills/$($item.Name)"
    }
}

# Sync agents/ - target only yearend-* md files
$agentsSrc = Join-Path $SourceRoot "agents"
if (Test-Path $agentsSrc) {
    # Remove target yearend-* agent files not in source
    $targetAgentItems = @(Get-ChildItem -File $targetAgents -Filter *.md -ErrorAction SilentlyContinue)
    foreach ($item in $targetAgentItems) {
        if ($item.Name -like "yearend-*") {
            $srcFile = Join-Path $agentsSrc $item.Name
            if (-not (Test-Path $srcFile)) {
                Write-Host "REMOVE: $($item.FullName)"
                Remove-Item -Force $item.FullName
            }
        }
    }

    # Copy agent files from source to target
    $srcAgentItems = @(Get-ChildItem -File $agentsSrc -Filter *.md)
    foreach ($item in $srcAgentItems) {
        $dest = Join-Path $targetAgents $item.Name
        Copy-Item -Force $item.FullName $dest
        Write-Host "COPY : agents/$($item.Name)"
    }
}

Write-Host "DONE"