param(
    [string]$GameDir = '',
    [string]$StateRoot = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PackageRoot = [IO.Path]::GetFullPath((Split-Path -Parent $MyInvocation.MyCommand.Path))
Import-Module (Join-Path $PackageRoot 'DiesIraeSteamR18Addon.Common.psm1') -Force
if ([string]::IsNullOrWhiteSpace($GameDir)) { $GameDir = Find-SteamGameDir }
$GameDir = [IO.Path]::GetFullPath($GameDir)
& (Join-Path $PackageRoot 'verify_r18_ko_steam.ps1') -GameDir $GameDir -StateRoot $StateRoot
$exe = Join-Path $GameDir 'malie_fabula.exe'
Start-Process -FilePath $exe -WorkingDirectory $GameDir
Write-Host "Acta est Fabula R-18 한국어판 실행: $exe"
