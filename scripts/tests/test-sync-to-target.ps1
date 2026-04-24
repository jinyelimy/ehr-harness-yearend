# scripts/tests/test-sync-to-target.ps1
# smoke test: 임시 소스/타깃 폴더를 만들고 sync-to-target.ps1 가
# 파일을 복사하고 삭제된 파일을 타깃에서도 제거하는지 확인한다 (/MIR 유사 동작).

param(
    [string]$ScriptPath = "$PSScriptRoot\..\sync-to-target.ps1"
)

$ErrorActionPreference = 'Stop'

$testRoot = Join-Path $env:TEMP ("yearend-harness-sync-test-" + [System.Guid]::NewGuid().ToString("N").Substring(0,8))
$srcRoot  = Join-Path $testRoot "src"
$tgtRoot  = Join-Path $testRoot "target"

New-Item -ItemType Directory -Force -Path "$srcRoot\skills\yearend-domain-map" | Out-Null
New-Item -ItemType Directory -Force -Path "$srcRoot\agents" | Out-Null
Set-Content "$srcRoot\skills\yearend-domain-map\SKILL.md" "v1"
Set-Content "$srcRoot\agents\yearend-investigator.md"     "v1"

New-Item -ItemType Directory -Force -Path "$tgtRoot\.claude" | Out-Null

$failed = 0

try {
    # 1st sync
    & $ScriptPath -SourceRoot $srcRoot -TargetClaudeDir "$tgtRoot\.claude"

    if (-not (Test-Path "$tgtRoot\.claude\skills\yearend-domain-map\SKILL.md")) {
        Write-Host "FAIL: 1st sync 로 domain-map SKILL.md 복사 안 됨"; $failed++
    }
    if (-not (Test-Path "$tgtRoot\.claude\agents\yearend-investigator.md")) {
        Write-Host "FAIL: 1st sync 로 agent 복사 안 됨"; $failed++
    }

    # 소스에서 파일 수정 + 삭제 후 2nd sync
    Set-Content "$srcRoot\skills\yearend-domain-map\SKILL.md" "v2"
    Remove-Item "$srcRoot\agents\yearend-investigator.md"

    & $ScriptPath -SourceRoot $srcRoot -TargetClaudeDir "$tgtRoot\.claude"

    if ((Get-Content "$tgtRoot\.claude\skills\yearend-domain-map\SKILL.md") -ne "v2") {
        Write-Host "FAIL: 2nd sync 로 내용 업데이트 안 됨"; $failed++
    }
    if (Test-Path "$tgtRoot\.claude\agents\yearend-investigator.md") {
        Write-Host "FAIL: 2nd sync 로 삭제 반영 안 됨"; $failed++
    }

    if ($failed -eq 0) {
        Write-Host "PASS: sync-to-target.ps1 smoke test OK"
    } else {
        Write-Host "FAILED tests: $failed"
        exit 1
    }
} finally {
    Remove-Item -Recurse -Force $testRoot -ErrorAction SilentlyContinue
}
