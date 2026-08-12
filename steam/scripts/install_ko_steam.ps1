param(
    [string]$GameDir = '',
    [string]$StateRoot = '',
    [switch]$AllowBackupExistingData5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ReleaseVersion = '1.0.3-steam-aa4'
$PackageRoot = [IO.Path]::GetFullPath((Split-Path -Parent $MyInvocation.MyCommand.Path))
$FilesRoot = Join-Path $PackageRoot 'files'

$BaselineHashes = [ordered]@{
    'data1.dat'       = '2EFE8AA9FFD16E23A6B80A098946079FA6E124F16C4264657685097238D576A2'
    'data2.dat'       = 'D900B788306D1F7016FDAA592D3839E0E0845529435B1E8D73931E9D3F17AB39'
    'steam_api.dll'   = 'FE302B9CF000B5B56B8F48DF9A6737FC43B1C225DB91306E92C779CAE0D2908D'
    'steam_appid.txt' = '3B61CBF22ECC4AF4C59FEFC5175143A4C5A594CFAEECC3A7AFFC7F11808C7ACA'
    'as.ini'          = '8E8EE181E1ED9F3F479690B0B743578EFD3A553B7A335D3E3666DDDFF39E8352'
}
$OriginalExeHash = 'CFDAA598422245A36B2333F1E923C8E808412D0360C86EF83D914ADF4D6EA926'
$OriginalData3Hash = '582E3A2DE4DFA9AFE0FE6550FE735F817433E49A9E551E6EA97D3DB68F8F7269'
$OriginalData4Hash = '096AE9AB25CF611187E83043A8DD80BAB6E8CB32249FA2E6FC95E0FCD6E82DB3'
$AllowedIniHashes = @(
    '328FEBBD70C45864A6A7FC62E854EF85083400265ACEE1E929FC248FB098BA1C',
    '97FC23AA552A07F4811BE9A2F14C4567B37C34B5D30B442D8B90D7A2ECF7CDEC'
)
$FontHash = 'BD505B1E18E9F3484011CE1014C0CF7FC73CC1338C790FA1AAB1A3027856638F'
$PackageHashes = [ordered]@{
    'malie.exe'                         = 'FF105876B39458E54CA8C4C8E5231CE013FB2AC4D3554B8611BD98C85C88CC30'
    'data3.dat'                         = '0DEA33565F85BB2B3321A0B8FA34B57E066DDE3DBEA739D2E5EB3474D00A6968'
    'data5.dat'                         = 'B91EBA7FF3702274A5A396EA86FAAEC92CB675936D6F6D59E3A355F4D0F78C8C'
    'data4.cn.dat'                      = '8945DC46FF25983174C31A501CFE1D3874CEDF4E02E13C670F772E0532C8A7FE'
    'malie_kr.ini'                      = '97FC23AA552A07F4811BE9A2F14C4567B37C34B5D30B442D8B90D7A2ECF7CDEC'
    'data\font\anticcezannepro.otf'   = $FontHash
    'data\font\tsukugopro-m.otf'      = $FontHash
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Assert-Hash([string]$Path, [string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "파일을 찾을 수 없습니다: $Path"
    }
    $actual = Get-Sha256 $Path
    if ($actual -ne $Expected.ToUpperInvariant()) {
        throw "해시 불일치: $Path`n예상: $Expected`n실제: $actual"
    }
}

function Get-NormalizedRoot([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path).TrimEnd([char[]]@('\', '/'))
    return $full + [IO.Path]::DirectorySeparatorChar
}

function Test-PathOverlap([string]$Left, [string]$Right) {
    $leftRoot = Get-NormalizedRoot $Left
    $rightRoot = Get-NormalizedRoot $Right
    return $leftRoot.StartsWith($rightRoot, [StringComparison]::OrdinalIgnoreCase) -or `
        $rightRoot.StartsWith($leftRoot, [StringComparison]::OrdinalIgnoreCase)
}

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
    if (@($parts | Where-Object { $_ -eq '' -or $_ -eq '.' -or $_ -eq '..' }).Count -gt 0) {
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
    $steamRoots = @($steamRoots | Select-Object -Unique)
    $libraries = @($steamRoots)
    foreach ($steamRoot in $steamRoots) {
        $vdf = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf -PathType Leaf) {
            foreach ($line in Get-Content -LiteralPath $vdf) {
                if ($line -match '^\s*"path"\s+"([^"]+)"') {
                    $libraries += ($matches[1] -replace '\\\\', '\')
                }
            }
        }
    }
    foreach ($library in @($libraries | Select-Object -Unique)) {
        $manifest = Join-Path $library 'steamapps\appmanifest_644540.acf'
        if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { continue }
        $text = Get-Content -Raw -LiteralPath $manifest
        if ($text -notmatch '"buildid"\s+"21665074"') {
            throw "지원하지 않는 Steam 빌드입니다: $manifest"
        }
        if ($text -match '"installdir"\s+"([^"]+)"') {
            $candidate = Join-Path (Join-Path $library 'steamapps\common') $matches[1]
            if (Test-Path -LiteralPath $candidate -PathType Container) {
                return [IO.Path]::GetFullPath($candidate)
            }
        }
    }
    throw 'Steam App 644540 설치 폴더를 자동으로 찾지 못했습니다. -GameDir를 지정하십시오.'
}

function Assert-GameStopped([string]$Directory) {
    $target = [IO.Path]::GetFullPath((Join-Path $Directory 'malie.exe'))
    foreach ($process in @(Get-Process -Name 'malie' -ErrorAction SilentlyContinue)) {
        try { $processPath = [IO.Path]::GetFullPath([string]$process.Path) } catch { continue }
        if ($processPath -eq $target) {
            throw "게임 실행 파일이 사용 중입니다: $processPath"
        }
    }
}

function Install-VerifiedFile([string]$Source, [string]$Destination, [string]$ExpectedHash) {
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
    if ([string]::IsNullOrWhiteSpace($localAppData)) {
        throw 'LocalApplicationData를 확인할 수 없습니다. 안전한 -StateRoot를 지정하십시오.'
    }
    $StateRoot = Join-Path $localAppData 'DiesIraeSteamKR'
}
$StateRoot = [IO.Path]::GetFullPath($StateRoot)

if (-not (Test-Path -LiteralPath $GameDir -PathType Container)) { throw "게임 폴더가 없습니다: $GameDir" }
if ((Test-PathOverlap $StateRoot $GameDir) -or (Test-PathOverlap $StateRoot $PackageRoot)) {
    throw '-StateRoot는 게임 또는 패키지 경로와 겹치지 않아야 합니다.'
}
foreach ($path in @($PackageRoot, $FilesRoot, $StateRoot, $GameDir)) {
    Assert-NoReparsePoint $path '관리'
}
$Tracked = @(
    'malie.exe', 'malie.ini', 'data3.dat', 'data4.cn.dat', 'data5.dat',
    'data\font\anticcezannepro.otf', 'data\font\tsukugopro-m.otf'
)
foreach ($relative in @($Tracked + @($BaselineHashes.Keys))) {
    [void](Get-SafeChildPath $GameDir ([string]$relative))
}

Assert-GameStopped $GameDir
$GameStateRoot = Join-Path $StateRoot (Get-PathId $GameDir)
$BackupRoot = Join-Path $GameStateRoot 'backups'
$ActiveManifest = Join-Path $GameStateRoot 'active_manifest.json'
if (Test-Path -LiteralPath $ActiveManifest -PathType Leaf) {
    throw "이미 활성화된 설치 상태가 있습니다: $ActiveManifest"
}

foreach ($entry in $BaselineHashes.GetEnumerator()) {
    Assert-Hash (Join-Path $GameDir $entry.Key) $entry.Value
}
Assert-Hash (Join-Path $GameDir 'malie.exe') $OriginalExeHash
Assert-Hash (Join-Path $GameDir 'data3.dat') $OriginalData3Hash
Assert-Hash (Join-Path $GameDir 'data4.cn.dat') $OriginalData4Hash
$iniPath = Join-Path $GameDir 'malie.ini'
if (-not (Test-Path -LiteralPath $iniPath -PathType Leaf)) { throw "malie.ini가 없습니다: $iniPath" }
$iniHash = Get-Sha256 $iniPath
if ($AllowedIniHashes -notcontains $iniHash) { throw "지원하지 않는 malie.ini 해시입니다: $iniHash" }
foreach ($fontRelative in @('data\font\anticcezannepro.otf', 'data\font\tsukugopro-m.otf')) {
    $fontPath = Join-Path $GameDir $fontRelative
    if (Test-Path -LiteralPath $fontPath -PathType Leaf) { Assert-Hash $fontPath $FontHash }
}
$existingData5 = Join-Path $GameDir 'data5.dat'
if ((Test-Path -LiteralPath $existingData5 -PathType Leaf) -and -not $AllowBackupExistingData5) {
    throw 'data5.dat가 이미 있습니다. 기존 파일을 함께 백업하려면 -AllowBackupExistingData5를 명시하십시오.'
}
foreach ($entry in $PackageHashes.GetEnumerator()) {
    Assert-Hash (Join-Path $FilesRoot $entry.Key) $entry.Value
}

$timestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [Guid]::NewGuid().ToString('N')
$backupDir = Join-Path $BackupRoot $timestamp
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$states = @()
foreach ($relative in $Tracked) {
    $target = Join-Path $GameDir $relative
    $exists = Test-Path -LiteralPath $target -PathType Leaf
    $state = [ordered]@{ relativePath=$relative; originalExists=[bool]$exists; originalSha256=$null; backupPath=$null }
    if ($exists) {
        $state.originalSha256 = Get-Sha256 $target
        $backupPath = Join-Path $backupDir $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backupPath) | Out-Null
        Copy-Item -LiteralPath $target -Destination $backupPath -Force
        Assert-Hash $backupPath $state.originalSha256
        $state.backupPath = $backupPath
    }
    $states += [pscustomobject]$state
}

try {
    Install-VerifiedFile (Join-Path $FilesRoot 'malie.exe') (Join-Path $GameDir 'malie.exe') $PackageHashes['malie.exe']
    Install-VerifiedFile (Join-Path $FilesRoot 'data3.dat') (Join-Path $GameDir 'data3.dat') $PackageHashes['data3.dat']
    Install-VerifiedFile (Join-Path $FilesRoot 'data5.dat') (Join-Path $GameDir 'data5.dat') $PackageHashes['data5.dat']
    Install-VerifiedFile (Join-Path $FilesRoot 'data4.cn.dat') (Join-Path $GameDir 'data4.cn.dat') $PackageHashes['data4.cn.dat']
    Install-VerifiedFile (Join-Path $FilesRoot 'malie_kr.ini') (Join-Path $GameDir 'malie.ini') $PackageHashes['malie_kr.ini']
    foreach ($fontRelative in @('data\font\anticcezannepro.otf', 'data\font\tsukugopro-m.otf')) {
        Install-VerifiedFile (Join-Path $FilesRoot $fontRelative) (Join-Path $GameDir $fontRelative) $PackageHashes[$fontRelative]
    }
    $installedHashes = [ordered]@{
        'malie.exe' = $PackageHashes['malie.exe']
        'data3.dat' = $PackageHashes['data3.dat']
        'data5.dat' = $PackageHashes['data5.dat']
        'data4.cn.dat' = $PackageHashes['data4.cn.dat']
        'malie.ini' = $PackageHashes['malie_kr.ini']
        'data\font\anticcezannepro.otf' = $PackageHashes['data\font\anticcezannepro.otf']
        'data\font\tsukugopro-m.otf' = $PackageHashes['data\font\tsukugopro-m.otf']
    }
    foreach ($entry in $installedHashes.GetEnumerator()) { Assert-Hash (Join-Path $GameDir $entry.Key) $entry.Value }
    foreach ($entry in $BaselineHashes.GetEnumerator()) { Assert-Hash (Join-Path $GameDir $entry.Key) $entry.Value }
    $manifest = [ordered]@{
        schema='dies-irae-steam-kr.install-manifest.v1'; releaseVersion=$ReleaseVersion
        installedUtc=[DateTime]::UtcNow.ToString('o'); gameDir=$GameDir; stateRoot=$StateRoot
        gameStateRoot=$GameStateRoot; backupDir=$backupDir; baselineHashes=$BaselineHashes
        originalStates=$states; installedHashes=$installedHashes
    }
    $json = $manifest | ConvertTo-Json -Depth 10
    [IO.File]::WriteAllText((Join-Path $backupDir 'install_manifest.json'), $json, [Text.UTF8Encoding]::new($false))
    New-Item -ItemType Directory -Force -Path $GameStateRoot | Out-Null
    [IO.File]::WriteAllText($ActiveManifest, $json, [Text.UTF8Encoding]::new($false))
} catch {
    foreach ($state in $states) {
        $target = Join-Path $GameDir $state.relativePath
        foreach ($suffix in @('.krpatch.incoming', '.krpatch.tmp')) {
            $temporary = $target + $suffix
            if (Test-Path -LiteralPath $temporary -PathType Leaf) { Remove-Item -LiteralPath $temporary -Force }
        }
        if ($state.originalExists) {
            Copy-Item -LiteralPath $state.backupPath -Destination $target -Force
            Assert-Hash $target $state.originalSha256
        } elseif (Test-Path -LiteralPath $target -PathType Leaf) {
            Remove-Item -LiteralPath $target -Force
        }
    }
    throw
}

Write-Host "Dies irae Steam 한국어 패치 $ReleaseVersion 설치 완료"
Write-Host "게임: $GameDir"
Write-Host "백업: $backupDir"
Write-Host 'verify_ko_steam.ps1로 설치 상태를 확인하십시오.'
