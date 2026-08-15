param(
    [string]$GameDir = '',
    [string]$StateRoot = ''
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
$manifest = Get-Content -Raw -LiteralPath $activeManifest -Encoding UTF8 | ConvertFrom-Json
if ($manifest.schema -ne 'dies-irae-steam-r18-kr.install-manifest.v1') { throw '지원하지 않는 설치 manifest입니다.' }
if ([IO.Path]::GetFullPath([string]$manifest.gameDir) -ne $GameDir) { throw 'manifest의 게임 경로가 다릅니다.' }
if ([IO.Path]::GetFullPath([string]$manifest.stateRoot) -ne $StateRoot) { throw 'manifest의 상태 경로가 다릅니다.' }

foreach ($entry in $manifest.aaRequiredHashes.PSObject.Properties) {
    Assert-Hash (Join-Path $GameDir $entry.Name) ([string]$entry.Value)
}
foreach ($entry in $manifest.installedHashes.PSObject.Properties) {
    $target = Join-Path $GameDir $entry.Name
    Assert-Hash $target ([string]$entry.Value)
    if (Test-Path -LiteralPath ($target + '.krr18.incoming') -PathType Leaf) {
        throw "임시 파일이 남아 있습니다: $target.krr18.incoming"
    }
}
foreach ($state in @($manifest.originalStates)) {
    if ([bool]$state.originalExists) {
        Assert-Hash ([string]$state.backupPath) ([string]$state.originalSha256)
    }
}
$backupManifest = Join-Path ([string]$manifest.backupDir) 'install_manifest.json'
if (-not (Test-Path -LiteralPath $backupManifest -PathType Leaf)) {
    throw "백업 manifest가 없습니다: $backupManifest"
}

Write-Host 'Dies irae Steam 개방 애드온 검증 PASS'
Write-Host "게임: $GameDir"
Write-Host "버전: $($manifest.releaseVersion)"
Write-Host "실행 파일: $(Join-Path $GameDir 'malie_fabula.exe')"
Write-Host "백업: $($manifest.backupDir)"
