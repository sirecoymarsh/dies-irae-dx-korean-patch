param(
    [string]$GameDir = '',
    [string]$StateRoot = '',
    [switch]$ForceRestore
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PackageRoot = [IO.Path]::GetFullPath((Split-Path -Parent $MyInvocation.MyCommand.Path))
Import-Module (Join-Path $PackageRoot 'DiesIraeSteamR18Addon.Common.psm1') -Force
$config = Get-AddonConfig

if ([string]::IsNullOrWhiteSpace($GameDir)) { $GameDir = Find-SteamGameDir }
$GameDir = [IO.Path]::GetFullPath($GameDir)
if ([string]::IsNullOrWhiteSpace($StateRoot)) {
    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    if ([string]::IsNullOrWhiteSpace($localAppData)) { throw '-StateRoot를 지정하십시오.' }
    $StateRoot = Join-Path $localAppData 'DiesIraeSteamKRR18'
}
$StateRoot = [IO.Path]::GetFullPath($StateRoot)
$gameStateRoot = Join-Path $StateRoot (Get-PathId $GameDir)
$activeManifest = Join-Path $gameStateRoot 'active_manifest.json'
if (-not (Test-Path -LiteralPath $activeManifest -PathType Leaf)) {
    throw "활성 개방 애드온 설치 manifest가 없습니다: $activeManifest"
}
Assert-GameStopped $GameDir
$manifest = Get-Content -Raw -LiteralPath $activeManifest -Encoding UTF8 | ConvertFrom-Json
if ($manifest.schema -ne 'dies-irae-steam-r18-kr.install-manifest.v1') { throw '지원하지 않는 설치 manifest입니다.' }
if ([IO.Path]::GetFullPath([string]$manifest.gameDir) -ne $GameDir) { throw 'manifest의 게임 경로가 다릅니다.' }
if ([IO.Path]::GetFullPath([string]$manifest.stateRoot) -ne $StateRoot) { throw 'manifest의 상태 경로가 다릅니다.' }

# 쓰기 전에 설치 상태와 모든 백업을 먼저 검증한다.
foreach ($entry in $manifest.aaRequiredHashes.PSObject.Properties) {
    Assert-Hash (Join-Path $GameDir $entry.Name) ([string]$entry.Value)
}
foreach ($entry in $manifest.installedHashes.PSObject.Properties) {
    $target = Join-Path $GameDir $entry.Name
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        if (-not $ForceRestore) { throw "설치 파일이 없습니다: $target" }
        continue
    }
    $actual = Get-Sha256 $target
    if ($actual -ne ([string]$entry.Value).ToUpperInvariant() -and -not $ForceRestore) {
        throw "설치 뒤 파일이 변경되었습니다: $target`n변경을 버리고 복원하려면 -ForceRestore를 사용하십시오."
    }
}
foreach ($state in @($manifest.originalStates)) {
    if ([bool]$state.originalExists) {
        Assert-Hash ([string]$state.backupPath) ([string]$state.originalSha256)
    }
}

$recoveryRoot = Join-Path $gameStateRoot ('uninstall_recovery_' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))
New-Item -ItemType Directory -Force -Path $recoveryRoot | Out-Null
$recoveryStates = @()
foreach ($state in @($manifest.originalStates)) {
    $target = Join-Path $GameDir ([string]$state.relativePath)
    $exists = Test-Path -LiteralPath $target -PathType Leaf
    $record = [ordered]@{ relativePath=[string]$state.relativePath; exists=[bool]$exists; sha256=$null; path=$null }
    if ($exists) {
        $record.sha256 = Get-Sha256 $target
        $copy = Join-Path $recoveryRoot ([string]$state.relativePath)
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $copy) | Out-Null
        Copy-Item -LiteralPath $target -Destination $copy -Force
        Assert-Hash $copy $record.sha256
        $record.path = $copy
    }
    $recoveryStates += [pscustomobject]$record
}

try {
    foreach ($state in @($manifest.originalStates)) {
        $target = Join-Path $GameDir ([string]$state.relativePath)
        if ([bool]$state.originalExists) {
            Restore-VerifiedFile ([string]$state.backupPath) $target ([string]$state.originalSha256)
        } elseif (Test-Path -LiteralPath $target -PathType Leaf) {
            Remove-Item -LiteralPath $target -Force
        }
    }
    foreach ($state in @($manifest.originalStates)) {
        $target = Join-Path $GameDir ([string]$state.relativePath)
        if ([bool]$state.originalExists) {
            Assert-Hash $target ([string]$state.originalSha256)
        } elseif (Test-Path -LiteralPath $target -PathType Leaf) {
            throw "새로 설치했던 파일이 제거되지 않았습니다: $target"
        }
    }
    foreach ($entry in $manifest.aaRequiredHashes.PSObject.Properties) {
        Assert-Hash (Join-Path $GameDir $entry.Name) ([string]$entry.Value)
    }
    Remove-Item -LiteralPath $activeManifest -Force
} catch {
    foreach ($record in $recoveryStates) {
        $target = Join-Path $GameDir ([string]$record.relativePath)
        if ([bool]$record.exists) {
            Restore-VerifiedFile ([string]$record.path) $target ([string]$record.sha256)
        } elseif (Test-Path -LiteralPath $target -PathType Leaf) {
            Remove-Item -LiteralPath $target -Force
        }
    }
    throw
}

Write-Host 'Dies irae Steam 개방 애드온 제거 및 설치 전 상태 복원 완료'
Write-Host "게임: $GameDir"
Write-Host '기존 Steam 한국어패치는 그대로 유지됩니다.'
Write-Host "원본 백업 보존 위치: $($manifest.backupDir)"
