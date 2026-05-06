<#
.SYNOPSIS
    Codex/PowerShell DB read-only guard for EHR yearend work.

.DESCRIPTION
    Reads a Codex hook JSON payload from stdin and blocks SQL CLI commands that
    attempt DML, DDL, PL/SQL execution, system packages, or @script.sql files.
    SELECT, WITH, EXPLAIN, and DESC-only usage passes.
#>

$ErrorActionPreference = 'Stop'

try {
    $payload = [Console]::In.ReadToEnd()
    $event = $payload | ConvertFrom-Json
} catch {
    [Console]::Error.WriteLine('db-read-only hook input parse failure; blocking for safety.')
    exit 2
}

$command = [string]$event.tool_input.command

if ([string]::IsNullOrWhiteSpace($command)) {
    exit 0
}

$sqlClientPattern = '(?i)(\bsqlplus\b|\bsqlcl\b|\bsqlcmd\b|\bimpdp\b|\bexpdp\b|\brman\b|\btibero\b|\btbsql\b)'
if ($command -notmatch $sqlClientPattern) {
    exit 0
}

if ($command -match '@\S+\.sql\b') {
    [Console]::Error.WriteLine('SQL script execution blocked: @script.sql is not inspectable by the hook.')
    exit 2
}

$dangerousPattern = '(?i)\b(DROP|TRUNCATE|DELETE|UPDATE|INSERT|MERGE|ALTER|CREATE|GRANT|REVOKE|UPSERT|EXEC|EXECUTE|CALL|DECLARE|BEGIN|DBMS_[A-Z_]+|UTL_[A-Z_]+)\b'
$dangerous = [regex]::Match($command, $dangerousPattern)

if ($dangerous.Success) {
    [Console]::Error.WriteLine("DB write/execute SQL blocked: $($dangerous.Value). Only SELECT/WITH/EXPLAIN/DESC are allowed.")
    exit 2
}

exit 0
