# scripts/tests/test-link-to-target.ps1
# smoke test: creates temporary src/target folders and verifies link-to-target.ps1
# correctly creates junctions to yearend-harness skills and agents

param(
    [string]$ScriptPath = "$PSScriptRoot\..\link-to-target.ps1"
)

$ErrorActionPreference = 'Stop'

# Create test root
$testRoot = Join-Path $env:TEMP ("yearend-harness-link-test-" + [System.Guid]::NewGuid().ToString("N").Substring(0,8))
$srcRoot  = Join-Path $testRoot "src"
$tgtRoot  = Join-Path $testRoot "target"

New-Item -ItemType Directory -Force -Path "$srcRoot\drafts\yearend-harness\skills\yearend-domain-map"   | Out-Null
New-Item -ItemType Directory -Force -Path "$srcRoot\drafts\yearend-harness\skills\yearend-chain-tracer" | Out-Null
New-Item -ItemType Directory -Force -Path "$srcRoot\drafts\yearend-harness\agents"                     | Out-Null
Set-Content -Path "$srcRoot\drafts\yearend-harness\skills\yearend-domain-map\SKILL.md"   -Value "dummy domain map"
Set-Content -Path "$srcRoot\drafts\yearend-harness\skills\yearend-chain-tracer\SKILL.md" -Value "dummy chain tracer"
Set-Content -Path "$srcRoot\drafts\yearend-harness\agents\yearend-investigator.md"       -Value "dummy agent"

New-Item -ItemType Directory -Force -Path "$tgtRoot\.claude" | Out-Null

$failed = 0

try {
    # Run the script
    & $ScriptPath -SourceRoot "$srcRoot\drafts\yearend-harness" -TargetClaudeDir "$tgtRoot\.claude"

    # Check 1: Verify two skill junctions and one agent junction were created
    $link1 = "$tgtRoot\.claude\skills\yearend-domain-map"
    $link2 = "$tgtRoot\.claude\skills\yearend-chain-tracer"
    $link3 = "$tgtRoot\.claude\agents\yearend-investigator.md"

    if (-not (Test-Path $link1)) { Write-Host "FAIL: $link1 not found"; $failed++ }
    if (-not (Test-Path $link2)) { Write-Host "FAIL: $link2 not found"; $failed++ }
    if (-not (Test-Path $link3)) { Write-Host "FAIL: $link3 not found"; $failed++ }

    # Check 2: Verify source file content visible through junctions
    if ((Get-Content "$link1\SKILL.md") -ne "dummy domain map") {
        Write-Host "FAIL: domain-map content mismatch through junction"; $failed++
    }
    if ((Get-Content "$link2\SKILL.md") -ne "dummy chain tracer") {
        Write-Host "FAIL: chain-tracer content mismatch through junction"; $failed++
    }

    # Check 3: Verify real-time reflection (source changes appear in target)
    Set-Content -Path "$srcRoot\drafts\yearend-harness\skills\yearend-domain-map\SKILL.md" -Value "changed"
    if ((Get-Content "$link1\SKILL.md") -ne "changed") {
        Write-Host "FAIL: junction not reflecting real-time changes"; $failed++
    }

    if ($failed -eq 0) {
        Write-Host "PASS: link-to-target.ps1 smoke test OK"
    } else {
        Write-Host "FAILED tests: $failed"
        exit 1
    }
} finally {
    # Cleanup
    Remove-Item -Recurse -Force $testRoot -ErrorAction SilentlyContinue
}
