param(
    [string]$GameDir = '',
    [string]$StateRoot = '',
    [switch]$ForceRestore
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Assert-Hash([string]$Path, [string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "파일을 찾을 수 없습니다: $Path" }
    $actual = Get-Sha256 $Path
    if ($actual -ne $Expected.ToUpperInvariant()) {
        throw "해시 불일치: $Path`n예상: $Expected`n실제: $actual"
    }
}

function Get-PathId([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes(([IO.Path]::GetFullPath($Path)).ToUpperInvariant())
        $digest = $sha.ComputeHash($bytes)
    } finally { $sha.Dispose() }
    return ((-join ($digest | ForEach-Object { $_.ToString('x2') })).Substring(0, 24))
}

function Find-SteamGameDir {
    $steamRoots = @()
    foreach ($key in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {
        try {
            $props = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
            foreach ($name in @('SteamPath', 'InstallPath')) {
                if ($props.PSObject.Properties.Name -contains $name -and $props.$name) {
                    $steamRoots += [IO.Path]::GetFullPath([string]$props.$name)
                }
            }
        } catch {}
    }
    $libraries = @($steamRoots)
    foreach ($steamRoot in @($steamRoots | Select-Object -Unique)) {
        $vdf = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf -PathType Leaf) {
            foreach ($line in Get-Content -LiteralPath $vdf) {
                if ($line -match '^\s*"path"\s+"([^"]+)"') { $libraries += ($matches[1] -replace '\\\\', '\') }
            }
        }
    }
    foreach ($library in @($libraries | Select-Object -Unique)) {
        $manifest = Join-Path $library 'steamapps\appmanifest_644540.acf'
        if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { continue }
        $text = Get-Content -Raw -LiteralPath $manifest
        if ($text -notmatch '"buildid"\s+"21665074"') { throw "지원하지 않는 Steam 빌드입니다: $manifest" }
        if ($text -match '"installdir"\s+"([^"]+)"') {
            $candidate = Join-Path (Join-Path $library 'steamapps\common') $matches[1]
            if (Test-Path -LiteralPath $candidate -PathType Container) { return [IO.Path]::GetFullPath($candidate) }
        }
    }
    throw 'Steam App 644540 설치 폴더를 찾지 못했습니다. -GameDir를 지정하십시오.'
}

function Assert-GameStopped([string]$Directory) {
    $target = [IO.Path]::GetFullPath((Join-Path $Directory 'malie.exe'))
    foreach ($process in @(Get-Process -Name 'malie' -ErrorAction SilentlyContinue)) {
        try { $processPath = [IO.Path]::GetFullPath([string]$process.Path) } catch { continue }
        if ($processPath -eq $target) { throw "게임 실행 파일이 사용 중입니다: $processPath" }
    }
}

function Restore-VerifiedFile([string]$Source, [string]$Destination, [string]$ExpectedHash) {
    Assert-Hash $Source $ExpectedHash
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    $incoming = "$Destination.krpatch.incoming"
    if (Test-Path -LiteralPath $incoming) { Remove-Item -LiteralPath $incoming -Force }
    Copy-Item -LiteralPath $Source -Destination $incoming -Force
    Assert-Hash $incoming $ExpectedHash
    Move-Item -LiteralPath $incoming -Destination $Destination -Force
    Assert-Hash $Destination $ExpectedHash
}

if ([string]::IsNullOrWhiteSpace($GameDir)) { $GameDir = Find-SteamGameDir }
$GameDir = [IO.Path]::GetFullPath($GameDir)
if ([string]::IsNullOrWhiteSpace($StateRoot)) {
    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    if ([string]::IsNullOrWhiteSpace($localAppData)) { throw '-StateRoot를 지정하십시오.' }
    $StateRoot = Join-Path $localAppData 'DiesIraeSteamKR'
}
$StateRoot = [IO.Path]::GetFullPath($StateRoot)
$GameStateRoot = Join-Path $StateRoot (Get-PathId $GameDir)
$ActiveManifest = Join-Path $GameStateRoot 'active_manifest.json'
if (-not (Test-Path -LiteralPath $ActiveManifest -PathType Leaf)) {
    throw "활성 설치 manifest가 없습니다: $ActiveManifest"
}
Assert-GameStopped $GameDir
$manifest = Get-Content -Raw -LiteralPath $ActiveManifest -Encoding UTF8 | ConvertFrom-Json
if ($manifest.schema -ne 'dies-irae-steam-kr.install-manifest.v1') { throw '지원하지 않는 설치 manifest입니다.' }
if ([IO.Path]::GetFullPath([string]$manifest.gameDir) -ne $GameDir) { throw 'manifest의 게임 경로가 다릅니다.' }
if ([IO.Path]::GetFullPath([string]$manifest.stateRoot) -ne $StateRoot) { throw 'manifest의 상태 경로가 다릅니다.' }

# 모든 검증을 쓰기 전에 끝낸다.
foreach ($entry in $manifest.baselineHashes.PSObject.Properties) {
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

$recoveryRoot = Join-Path $GameStateRoot ('uninstall_recovery_' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))
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
        } else {
            if (Test-Path -LiteralPath $target -PathType Leaf) { Remove-Item -LiteralPath $target -Force }
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
    Remove-Item -LiteralPath $ActiveManifest -Force
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

Write-Host 'Dies irae Steam 한국어 패치 제거 및 설치 전 상태 복원 완료'
Write-Host "게임: $GameDir"
Write-Host "원본 백업 보존 위치: $($manifest.backupDir)"
