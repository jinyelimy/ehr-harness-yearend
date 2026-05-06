# scripts/tests/test-codex-hooks-json.ps1
# Regression test for plugins/ehr-yearend-harness/hooks/codex-hooks.json.
#
# Background:
#   Earlier review flagged a concern that the Codex hook was Bash-based and might not
#   fire on Windows when Codex emits PowerShell-only commands. Inspection shows the
#   hook command itself is invoked via `powershell -NoProfile ...` (cross-platform on
#   Windows; the `matcher` field "Bash" refers to the Codex tool name, not the host
#   shell). This test pins that contract:
#
#   1. The codex-hooks.json file is well-formed.
#   2. Its PreToolUse[0].matcher targets "Bash" (the Codex tool name).
#   3. The first hook's command literally invokes "powershell" (so it runs on Windows
#      and any platform where pwsh/powershell is on PATH).
#   4. End-to-end: feeding the same payload shape Codex sends (JSON with
#      tool_name/tool_input.command) into that exact command line yields:
#         - exit 0 for SELECT
#         - exit 0 for DESC
#         - exit 2 for DELETE
#         - exit 2 for @script.sql
#         - exit 0 for non-DB shell text
#
# This guards against future edits that replace `powershell` with `bash` (which would
# break Windows users) or that drop the Bash matcher.

param(
    [string]$HooksJsonPath = "$PSScriptRoot\..\..\plugins\ehr-yearend-harness\hooks\codex-hooks.json"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $HooksJsonPath)) {
    throw "HooksJsonPath does not exist: $HooksJsonPath"
}

$failed = 0
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        Write-Host "FAIL: $Message"
        $script:failed++
    }
}

# 1. Parse
$raw = Get-Content -Raw -Encoding UTF8 -LiteralPath $HooksJsonPath
$config = $null
try {
    $config = $raw | ConvertFrom-Json
} catch {
    Write-Host "FAIL: codex-hooks.json is not valid JSON: $_"
    exit 1
}

# 2. Structure
$preToolUse = $config.hooks.PreToolUse
Assert-True ($null -ne $preToolUse) "hooks.PreToolUse must exist"
Assert-True ($preToolUse.Count -ge 1) "hooks.PreToolUse must have at least one entry"

$entry = $preToolUse[0]
Assert-True ($entry.matcher -eq 'Bash') "hooks.PreToolUse[0].matcher must be 'Bash' (Codex tool name)"
Assert-True ($entry.hooks.Count -ge 1) "hooks.PreToolUse[0].hooks must have at least one hook"

$hook = $entry.hooks[0]
Assert-True ($hook.type -eq 'command') "hook type must be 'command'"

# 3. Command must invoke powershell (Windows-friendly, not bash).
$command = [string]$hook.command
Assert-True ($command -match '(?i)^\s*powershell\b') "hook command must start with 'powershell' so it runs on Windows. Got: $($command.Substring(0, [Math]::Min(60, $command.Length)))..."
Assert-True ($command -notmatch '(?i)^\s*bash\b') "hook command must not start with 'bash' (would not run on Windows by default)"

# 4. End-to-end: extract the inline -Command body and invoke it as Codex would.
$bodyMatch = [regex]::Match($command, '(?s)powershell\s+-NoProfile\s+-ExecutionPolicy\s+Bypass\s+-Command\s+"(?<body>.*)"\s*$')
Assert-True ($bodyMatch.Success) "Could not extract -Command body from hook command"
$scriptBody = $bodyMatch.Groups['body'].Value
# Within JSON-quoted PowerShell -Command, double-quoted strings escape inner double-quotes.
# JSON delivered the body with escaped quotes already collapsed to plain ", so re-escape any literal double quotes
# that should be PowerShell-literal. Codex passes the field verbatim to the shell.
# In practice the script body has no inner double quotes that need adjustment; pass as-is.

function Invoke-HookCommand {
    param([string]$ShellCommand)

    $payload = @{
        hook_event_name = 'PreToolUse'
        tool_name       = 'Bash'
        tool_input      = @{ command = $ShellCommand }
    } | ConvertTo-Json -Depth 5 -Compress

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $payload | & powershell -NoProfile -ExecutionPolicy Bypass -Command $scriptBody 2>$null | Out-Null
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

$cases = @(
    @{ Name = 'SELECT (allow)';                Cmd = 'sqlplus user/pass@DEV -e "SELECT 1 FROM DUAL"';  Expected = 0 },
    @{ Name = 'DESC (allow)';                  Cmd = 'tbsql user/pass -c "DESC TCPN843"';              Expected = 0 },
    @{ Name = 'DELETE (block)';                Cmd = 'sqlplus user/pass@DEV -e "DELETE FROM TCPN843"'; Expected = 2 },
    @{ Name = '@script.sql (block)';           Cmd = 'sqlplus user/pass@DEV @dangerous.sql';           Expected = 2 },
    @{ Name = 'non-DB shell text (allow)';     Cmd = 'Get-ChildItem -Recurse -Filter *.sql';           Expected = 0 }
)

foreach ($c in $cases) {
    $code = Invoke-HookCommand -ShellCommand $c.Cmd
    Assert-True ($code -eq $c.Expected) "$($c.Name): expected exit $($c.Expected), got $code"
}

if ($failed -gt 0) {
    Write-Host "FAILED tests: $failed"
    exit 1
}

Write-Host "PASS: codex-hooks.json contract + end-to-end behavior OK"
