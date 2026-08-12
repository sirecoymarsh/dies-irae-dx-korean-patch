param(
    [string]$GameDir = '',
    [string]$StateRoot = ''
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
$manifest = Get-Content -Raw -LiteralPath $ActiveManifest -Encoding UTF8 | ConvertFrom-Json
if ($manifest.schema -ne 'dies-irae-steam-kr.install-manifest.v1') { throw '지원하지 않는 설치 manifest입니다.' }
if ([IO.Path]::GetFullPath([string]$manifest.gameDir) -ne $GameDir) { throw 'manifest의 게임 경로가 다릅니다.' }
if ([IO.Path]::GetFullPath([string]$manifest.stateRoot) -ne $StateRoot) { throw 'manifest의 상태 경로가 다릅니다.' }

foreach ($entry in $manifest.baselineHashes.PSObject.Properties) {
    Assert-Hash (Join-Path $GameDir $entry.Name) ([string]$entry.Value)
}
foreach ($entry in $manifest.installedHashes.PSObject.Properties) {
    $target = Join-Path $GameDir $entry.Name
    Assert-Hash $target ([string]$entry.Value)
    foreach ($suffix in @('.krpatch.incoming', '.krpatch.tmp')) {
        if (Test-Path -LiteralPath ($target + $suffix) -PathType Leaf) { throw "임시 파일이 남아 있습니다: $target$suffix" }
    }
}
foreach ($state in @($manifest.originalStates)) {
    if ([bool]$state.originalExists) {
        Assert-Hash ([string]$state.backupPath) ([string]$state.originalSha256)
    }
}
$backupManifest = Join-Path ([string]$manifest.backupDir) 'install_manifest.json'
if (-not (Test-Path -LiteralPath $backupManifest -PathType Leaf)) { throw "백업 manifest가 없습니다: $backupManifest" }

Write-Host 'Dies irae Steam 한국어 패치 검증 PASS'
Write-Host "게임: $GameDir"
Write-Host "버전: $($manifest.releaseVersion)"
Write-Host "백업: $($manifest.backupDir)"
