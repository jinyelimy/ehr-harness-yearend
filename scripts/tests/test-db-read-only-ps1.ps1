# scripts/tests/test-db-read-only-ps1.ps1
# Smoke test for the Codex/PowerShell DB read-only guard.

param(
    [string]$ScriptPath = "$PSScriptRoot\..\..\plugins\ehr-yearend-harness\scripts\db-read-only.ps1"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ScriptPath)) {
    throw "ScriptPath does not exist: $ScriptPath"
}

function Invoke-Guard {
    param(
        [string]$Command
    )

    $payload = @{
        hook_event_name = 'PreToolUse'
        tool_name = 'Bash'
        tool_input = @{
            command = $Command
        }
    } | ConvertTo-Json -Depth 5 -Compress

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $payload | & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath 2>$null
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

$failed = 0

$safeCode = Invoke-Guard 'sqlplus user/pass@"DEV" -e "SELECT * FROM TCPN843 WHERE ROWNUM = 1"'
if ($safeCode -ne 0) {
    Write-Host "FAIL: SELECT should pass, exit=$safeCode"
    $failed++
}

$descCode = Invoke-Guard 'tbsql user/pass -c "DESC TCPN843"'
if ($descCode -ne 0) {
    Write-Host "FAIL: DESC should pass, exit=$descCode"
    $failed++
}

$deleteCode = Invoke-Guard 'sqlplus user/pass@"DEV" -e "DELETE FROM TCPN843 WHERE 1=1"'
if ($deleteCode -ne 2) {
    Write-Host "FAIL: DELETE should block with exit 2, exit=$deleteCode"
    $failed++
}

$scriptCode = Invoke-Guard 'sqlplus user/pass@"DEV" @dangerous.sql'
if ($scriptCode -ne 2) {
    Write-Host "FAIL: @script.sql should block with exit 2, exit=$scriptCode"
    $failed++
}

$nonDbCode = Invoke-Guard 'Get-ChildItem -Recurse -Filter *.sql'
if ($nonDbCode -ne 0) {
    Write-Host "FAIL: non-DB shell command should pass, exit=$nonDbCode"
    $failed++
}

if ($failed -gt 0) {
    Write-Host "FAILED tests: $failed"
    exit 1
}

Write-Host "PASS: db-read-only.ps1 smoke test OK"
