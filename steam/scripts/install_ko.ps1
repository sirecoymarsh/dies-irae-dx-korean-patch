param(
    [Parameter(Mandatory=$true)]
    [string]$GameDir,
    [string]$StateRoot = '',
    [switch]$AllowBackupExistingOverlays
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ReleaseVersion = '1.0.0-steam-build21665074-rc7'
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$FilesRoot = Join-Path $PackageRoot 'files'
$GameDir = [IO.Path]::GetFullPath($GameDir)

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
        throw 'LocalApplicationData 경로를 확인할 수 없습니다. 게임 및 패키지 밖의 안전한 -StateRoot를 직접 지정하십시오.'
    }
    $StateRoot = Join-Path $localAppData 'DiesIraeSteamKR'
}
$StateRoot = [IO.Path]::GetFullPath($StateRoot)
if ((Test-PathOverlap $StateRoot $GameDir) -or (Test-PathOverlap $StateRoot $PackageRoot)) {
    throw '-StateRoot는 게임 또는 패키지 경로와 겹치지 않아야 합니다.'
}
$GameStateRoot = Join-Path $StateRoot (Get-PathId $GameDir)
$BackupRoot = Join-Path $GameStateRoot 'backups'
$ActiveManifest = Join-Path $GameStateRoot 'active_manifest.json'

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

function Assert-GameStopped([string]$Directory) {
    foreach ($name in @('malie')) {
        foreach ($process in @(Get-Process -Name $name -ErrorAction SilentlyContinue)) {
            try { $processPath = [IO.Path]::GetFullPath([string]$process.Path) } catch { continue }
            $targetPath = [IO.Path]::GetFullPath((Join-Path $Directory ($name + '.exe')))
            if ($processPath -eq $targetPath) {
                throw "게임 실행 파일이 사용 중입니다: $processPath"
            }
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

Assert-NoReparsePoint $PackageRoot 'PackageRoot'
Assert-NoReparsePoint $FilesRoot 'FilesRoot'
Assert-NoReparsePoint $StateRoot 'StateRoot'
Assert-NoReparsePoint $GameDir 'GameDir'
foreach ($relative in @('malie.exe', 'malie.ini', 'data4.cn.dat', 'data\font\anticcezannepro.otf', 'data\font\tsukugopro-m.otf')) {
    [void](Get-SafeChildPath $GameDir $relative)
}

if (-not (Test-Path -LiteralPath $GameDir -PathType Container)) {
    throw "게임 폴더를 찾을 수 없습니다: $GameDir"
}
Assert-GameStopped $GameDir
if (Test-Path -LiteralPath $ActiveManifest -PathType Leaf) {
    throw "이미 활성화된 패치 설치 상태가 있습니다: $ActiveManifest"
}

$baseline = [ordered]@{
    'data1.dat' = '2EFE8AA9FFD16E23A6B80A098946079FA6E124F16C4264657685097238D576A2'
    'data2.dat' = 'D900B788306D1F7016FDAA592D3839E0E0845529435B1E8D73931E9D3F17AB39'
    'data3.dat' = '582E3A2DE4DFA9AFE0FE6550FE735F817433E49A9E551E6EA97D3DB68F8F7269'
    'data4.cn.dat' = 'A00FAB55E1E8FD1C49E2D13AA8E5F399D7CA958FB369891633B0CAE2FB89584B'
    'malie.exe' = 'CFDAA598422245A36B2333F1E923C8E808412D0360C86EF83D914ADF4D6EA926'
    'malie.ini' = '6C84095D163250297A506EFA191BA930DD2D87440758C40DF45A3F0D88E24B94'
}
foreach ($entry in $baseline.GetEnumerator()) {
    Assert-Hash (Join-Path $GameDir $entry.Key) $entry.Value
}

$packageHashes = [ordered]@{
    'data4.cn.dat' = '096AE9AB25CF611187E83043A8DD80BAB6E8CB32249FA2E6FC95E0FCD6E82DB3'
    'data\font\anticcezannepro.otf' = 'BD505B1E18E9F3484011CE1014C0CF7FC73CC1338C790FA1AAB1A3027856638F'
    'data\font\tsukugopro-m.otf' = 'BD505B1E18E9F3484011CE1014C0CF7FC73CC1338C790FA1AAB1A3027856638F'
    'malie_kr.ini' = '97FC23AA552A07F4811BE9A2F14C4567B37C34B5D30B442D8B90D7A2ECF7CDEC'
}
foreach ($entry in $packageHashes.GetEnumerator()) {
    Assert-Hash (Join-Path $FilesRoot $entry.Key) $entry.Value
}

$timestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [Guid]::NewGuid().ToString('N')
$backupDir = Join-Path $BackupRoot $timestamp
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$tracked = @('malie.ini', 'data4.cn.dat', 'data\font\anticcezannepro.otf', 'data\font\tsukugopro-m.otf')
$states = @()
foreach ($relative in $tracked) {
    $target = Join-Path $GameDir $relative
    $exists = Test-Path -LiteralPath $target -PathType Leaf
    $state = [ordered]@{
        relativePath = $relative
        originalExists = [bool]$exists
        originalSha256 = $null
        backupPath = $null
    }
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
        Install-VerifiedFile (Join-Path $FilesRoot 'malie_kr.ini') (Join-Path $GameDir 'malie.ini') $packageHashes['malie_kr.ini']
    Install-VerifiedFile (Join-Path $FilesRoot 'data4.cn.dat') (Join-Path $GameDir 'data4.cn.dat') $packageHashes['data4.cn.dat']
    $fontDir = Join-Path $GameDir 'data\font'
    New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
    Install-VerifiedFile (Join-Path $FilesRoot 'data\font\anticcezannepro.otf') (Join-Path $fontDir 'anticcezannepro.otf') $packageHashes['data\font\anticcezannepro.otf']
    Install-VerifiedFile (Join-Path $FilesRoot 'data\font\tsukugopro-m.otf') (Join-Path $fontDir 'tsukugopro-m.otf') $packageHashes['data\font\tsukugopro-m.otf']

    $installedHashes = [ordered]@{
        'malie.ini' = $packageHashes['malie_kr.ini']
        'data4.cn.dat' = $packageHashes['data4.cn.dat']
        'data\font\anticcezannepro.otf' = $packageHashes['data\font\anticcezannepro.otf']
        'data\font\tsukugopro-m.otf' = $packageHashes['data\font\tsukugopro-m.otf']
    }
    foreach ($entry in $installedHashes.GetEnumerator()) {
        Assert-Hash (Join-Path $GameDir $entry.Key) $entry.Value
    }
    $manifest = [ordered]@{
        schema = 'dies-irae-steam-kr.install-manifest.v1'
        releaseVersion = $ReleaseVersion
        installedUtc = [DateTime]::UtcNow.ToString('o')
        gameDir = $GameDir
        stateRoot = $StateRoot
        gameStateRoot = $GameStateRoot
        backupDir = $backupDir
        originalStates = $states
        installedHashes = $installedHashes
    }
    $json = $manifest | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText((Join-Path $backupDir 'install_manifest.json'), $json, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($ActiveManifest, $json, [Text.UTF8Encoding]::new($false))
} catch {
    foreach ($state in $states) {
        $target = Join-Path $GameDir $state.relativePath
        foreach ($suffix in @('.krpatch.incoming', '.krpatch.tmp')) {
            $temporary = $target + $suffix
            if (Test-Path -LiteralPath $temporary -PathType Leaf) {
                Remove-Item -LiteralPath $temporary -Force
            }
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
Write-Host 'verify_ko.ps1을 실행한 뒤 Steam에서 게임을 시작하거나 malie.exe를 실행하십시오.'
