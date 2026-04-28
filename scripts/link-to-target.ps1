<#
.SYNOPSIS
    Yearend Harness 瑜??源?EHR ?꾨줈?앺듃??.claude/ ???뺤뀡?쇰줈 ?곌껐?쒕떎.
.DESCRIPTION
    plugins/ehr-yearend-harness/skills/* 怨?agents/* ???源?.claude/skills/ 諛?.claude/agents/
    ?꾨옒??Windows directory junction ?쇰줈 ?곌껐?쒕떎. ?먯씠?꾪듃 md ?뚯씪? ?붾젆?곕━媛 ?꾨땲誘濡?    ?뺤뀡 ????섎뱶留곹겕(mklink /H) 濡??곌껐?쒕떎.
.PARAMETER SourceRoot
    plugins/ehr-yearend-harness ???덈? 寃쎈줈.
.PARAMETER TargetClaudeDir
    ?源??꾨줈?앺듃??.claude ?붾젆?곕━ ?덈? 寃쎈줈.
.EXAMPLE
    .\scripts\link-to-target.ps1 `
        -SourceRoot   "C:\yelingg\ehr-harness-yearend\plugins\ehr-yearend-harness" `
        -TargetClaudeDir "C:\Users\jinyelimy\isu-hr\EHR_HR50\.claude"
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$SourceRoot,
    [Parameter(Mandatory=$true)]
    [string]$TargetClaudeDir
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $SourceRoot)) {
    throw "SourceRoot 媛 議댁옱?섏? ?딆쓬: $SourceRoot"
}
$targetSkills = Join-Path $TargetClaudeDir "skills"
$targetAgents = Join-Path $TargetClaudeDir "agents"
New-Item -ItemType Directory -Force -Path $targetSkills | Out-Null
New-Item -ItemType Directory -Force -Path $targetAgents | Out-Null
function New-DirectoryJunction {
    param(
        [string]$Link,
        [string]$TargetPath
    )
    if (Test-Path $Link) {
        $item = Get-Item $Link -Force
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Write-Host "SKIP ?뺤뀡 ?대? 議댁옱: $Link"
            return
        } else {
            throw "?뺤뀡???꾨땶 ??ぉ???대? 議댁옱: $Link"
        }
    }
    Write-Host "CREATE ?뺤뀡: $Link -> $TargetPath"
    cmd /c mklink /J "`"$Link`"" "`"$TargetPath`"" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "mklink ?ㅽ뙣: $Link -> $TargetPath"
    }
}
function New-FileHardLink {
    param(
        [string]$Link,
        [string]$TargetPath
    )
    if (Test-Path $Link) {
        Write-Host "SKIP ?뚯씪 ?대? 議댁옱: $Link"
        return
    }
    if (-not (Test-Path $TargetPath)) {
        throw "?먮낯 ?뚯씪??議댁옱?섏? ?딆쓬: $TargetPath"
    }
    Write-Host "CREATE ?섎뱶留곹겕: $Link -> $TargetPath"
    cmd /c mklink /H "`"$Link`"" "`"$TargetPath`"" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "mklink /H ?ㅽ뙣: $Link -> $TargetPath"
    }
}
$skillsSrc = Join-Path $SourceRoot "skills"
if (Test-Path $skillsSrc) {
    Get-ChildItem -Directory -Path $skillsSrc | ForEach-Object {
        $link   = Join-Path $targetSkills $_.Name
        $target = $_.FullName
        New-DirectoryJunction -Link $link -TargetPath $target
    }
}
$agentsSrc = Join-Path $SourceRoot "agents"
if (Test-Path $agentsSrc) {
    Get-ChildItem -File -Path $agentsSrc -Filter *.md | ForEach-Object {
        $link   = Join-Path $targetAgents $_.Name
        $target = $_.FullName
        New-FileHardLink -Link $link -TargetPath $target
    }
}
Write-Host "DONE"