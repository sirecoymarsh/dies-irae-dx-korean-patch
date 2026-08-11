param(
    [Parameter(Mandatory=$true)]
    [string]$GameDir,
    [string]$StateRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$GameDir = [IO.Path]::GetFullPath($GameDir)
function Assert-NoReparsePoint([string]$Path, [string]$Label) {
    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -LiteralPath $Path -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "$Label 경로에 링크 또는 재분석 지점이 있습니다: $Path"
        }
    }
}

function Get-SafeChildPath([string]$Root, [string]$Relative) {
    if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative)) {
        throw "안전하지 않은 상대 경로입니다: $Relative"
    }
    $parts = @($Relative -split '[\\/]')
    if ($parts.Count -eq 0 -or @($parts | Where-Object { $_ -eq '' -or $_ -eq '.' -or $_ -eq '..' }).Count -gt 0) {
        throw "안전하지 않은 상대 경로입니다: $Relative"
    }
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd([char[]]@('\', '/'))
    $rootPrefix = $rootFull + [IO.Path]::DirectorySeparatorChar
    $target = [IO.Path]::GetFullPath((Join-Path $rootFull $Relative))
    if (-not $target.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "관리 경로가 루트를 벗어났습니다: $target"
    }
    Assert-NoReparsePoint $rootFull 'root'
    $current = $rootFull
    foreach ($part in $parts) {
        $current = Join-Path $current $part
        Assert-NoReparsePoint $current 'managed'
    }
    return $target
}

function Get-PathId([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes(([IO.Path]::GetFullPath($Path)).ToUpperInvariant())
        $digest = $sha.ComputeHash($bytes)
    } finally {
        $sha.Dispose()
    }
    return ((-join ($digest | ForEach-Object { $_.ToString('x2') })).Substring(0, 24))
}
if ([string]::IsNullOrWhiteSpace($StateRoot)) {
    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    if ([string]::IsNullOrWhiteSpace($localAppData)) {
        throw 'LocalApplicationData 경로를 확인할 수 없습니다. 설치 때 사용한 -StateRoot를 지정하십시오.'
    }
    $StateRoot = Join-Path $localAppData 'DiesIraeSteamKR'
}
$StateRoot = [IO.Path]::GetFullPath($StateRoot)
Assert-NoReparsePoint $StateRoot 'StateRoot'
Assert-NoReparsePoint $GameDir 'GameDir'
$GameStateRoot = Join-Path $StateRoot (Get-PathId $GameDir)
$active = Join-Path $GameStateRoot 'active_manifest.json'
function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}
if (-not (Test-Path -LiteralPath $active -PathType Leaf)) {
    throw "활성 설치 기록을 찾을 수 없습니다: $active"
}
$manifest = Get-Content -LiteralPath $active -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-NoReparsePoint $active 'ActiveManifest'
if ([string]$manifest.schema -ne 'dies-irae-steam-kr.install-manifest.v1') {
    throw '설치 기록 스키마가 일치하지 않습니다.'
}
$expectedTracked = @('malie.ini', 'data4.cn.dat', 'data\font\anticcezannepro.otf', 'data\font\tsukugopro-m.otf')
$installedNames = @($manifest.installedHashes.PSObject.Properties | ForEach-Object { [string]$_.Name })
$nameDifference = @(Compare-Object -ReferenceObject $expectedTracked -DifferenceObject $installedNames)
if ($nameDifference.Count -ne 0 -or $installedNames.Count -ne $expectedTracked.Count) {
    throw '설치 기록의 패치 파일 집합이 일치하지 않습니다.'
}
foreach ($property in $manifest.installedHashes.PSObject.Properties) {
    [void](Get-SafeChildPath $GameDir ([string]$property.Name))
    if ([string]$property.Value -notmatch '^[0-9A-Fa-f]{64}$') {
        throw '설치 기록에 잘못된 SHA-256이 있습니다.'
    }
}
$manifestGameDir = [IO.Path]::GetFullPath([string]$manifest.gameDir)
$manifestStateRoot = [IO.Path]::GetFullPath([string]$manifest.stateRoot)
if ($manifestGameDir -ne $GameDir -or $manifestStateRoot -ne $StateRoot) {
    throw '활성 설치 기록의 게임 또는 상태 경로가 현재 인수와 일치하지 않습니다.'
}
$failures = @()
foreach ($property in $manifest.installedHashes.PSObject.Properties) {
    $target = Join-Path $GameDir $property.Name
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        $failures += "누락 $target"
        continue
    }
    $actual = Get-Sha256 $target
    $expected = ([string]$property.Value).ToUpperInvariant()
    if ($actual -ne $expected) { $failures += "해시 불일치 $target 예상=$expected 실제=$actual" }
}
$originalArchives = [ordered]@{
    'data1.dat' = '2EFE8AA9FFD16E23A6B80A098946079FA6E124F16C4264657685097238D576A2'
    'data2.dat' = 'D900B788306D1F7016FDAA592D3839E0E0845529435B1E8D73931E9D3F17AB39'
    'data3.dat' = '582E3A2DE4DFA9AFE0FE6550FE735F817433E49A9E551E6EA97D3DB68F8F7269'
    'malie.exe' = 'CFDAA598422245A36B2333F1E923C8E808412D0360C86EF83D914ADF4D6EA926'
}
foreach ($entry in $originalArchives.GetEnumerator()) {
    $target = Join-Path $GameDir $entry.Key
    if ((Get-Sha256 $target) -ne $entry.Value) { $failures += "원본 변조 $target" }
}
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    throw "검증에 실패했습니다. 문제 수: $($failures.Count)"
}
Write-Host "버전: $($manifest.releaseVersion)"
Write-Host '설치된 패치 파일이 정확하며 data1~data3 및 실행 파일은 원본 그대로입니다.'
