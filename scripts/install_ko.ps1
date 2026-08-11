param(
    [Parameter(Mandatory=$true)]
    [string]$GameDir,
    [string]$StateRoot = '',
    [switch]$AllowBackupExistingOverlays
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ReleaseVersion = '1.0.0-rc1-ui-final'
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
    $StateRoot = Join-Path $localAppData 'DiesIraeDXKR'
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
    foreach ($name in @('malie', 'malie_fabula')) {
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

function Hex-Bytes([string]$Hex) {
    $clean = $Hex -replace '[^0-9A-Fa-f]', ''
    if (($clean.Length % 2) -ne 0) { throw "잘못된 16진수 바이트열입니다: $Hex" }
    $bytes = New-Object byte[] ($clean.Length / 2)
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $bytes[$i] = [Convert]::ToByte($clean.Substring($i * 2, 2), 16)
    }
    return $bytes
}

function Patch-Executable(
    [string]$Path,
    [object[]]$Patches,
    [string]$ExpectedOriginalHash,
    [string]$ExpectedPatchedHash
) {
    Assert-Hash $Path $ExpectedOriginalHash
    $bytes = [IO.File]::ReadAllBytes($Path)
    $occupied = New-Object 'System.Collections.Generic.HashSet[long]'
    foreach ($patch in $Patches) {
        $offset = [long]$patch.Offset
        $before = Hex-Bytes ([string]$patch.BeforeHex)
        $after = Hex-Bytes ([string]$patch.AfterHex)
        if ($before.Length -ne $after.Length) { throw '패치 전후 바이트 길이가 다릅니다.' }
        if ($offset -lt 0 -or ($offset + $before.Length) -gt $bytes.Length) {
            throw ("실행 파일 패치 범위가 파일을 벗어났습니다(0x{0:X}): {1}" -f $offset, $Path)
        }
        for ($i = 0; $i -lt $before.Length; $i++) {
            $position = $offset + $i
            if (-not $occupied.Add($position)) {
                throw ("실행 파일 패치 범위가 겹칩니다(0x{0:X}): {1}" -f $position, $Path)
            }
            if ($bytes[$position] -ne $before[$i]) {
                throw ("실행 파일 패치 지점 불일치(0x{0:X}): {1}" -f $position, $Path)
            }
            $bytes[$position] = $after[$i]
        }
    }
    $tmp = "$Path.krpatch.tmp"
    [IO.File]::WriteAllBytes($tmp, $bytes)
    Assert-Hash $tmp $ExpectedPatchedHash
    Move-Item -LiteralPath $tmp -Destination $Path -Force
    Assert-Hash $Path $ExpectedPatchedHash
}

Assert-NoReparsePoint $PackageRoot 'PackageRoot'
Assert-NoReparsePoint $FilesRoot 'FilesRoot'
Assert-NoReparsePoint $StateRoot 'StateRoot'
Assert-NoReparsePoint $GameDir 'GameDir'
foreach ($relative in @('malie.exe', 'malie_fabula.exe', 'malie.ini', 'data5.dat', 'data6.dat', 'data\font\anticcezannepro.otf', 'data\font\tsukugopro-m.otf')) {
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
    'data3.dat' = 'FEA45CEF0195997C6ECBEC1DE39F7567F4D95956ACA7A7D43CA7EA1D36E11E8E'
    'data4.dat' = '16A001365E7AE6D98BC30838EF3727AC4DA600AA5EC5F573C8475EF8A7D92C63'
    'malie.exe' = '0BF8A624C6A89E68217ADDB736A5E52AC3DFD544D2D215FB6814A95DDE5C7B00'
    'malie_fabula.exe' = '39ABE2643EF5C05A5637EDBB49CD1C4B7EAE4EC732D535619D16514EA9323536'
    'malie.ini' = '328FEBBD70C45864A6A7FC62E854EF85083400265ACEE1E929FC248FB098BA1C'
}
foreach ($entry in $baseline.GetEnumerator()) {
    Assert-Hash (Join-Path $GameDir $entry.Key) $entry.Value
}

$packageHashes = [ordered]@{
    'data5.dat' = 'B91EBA7FF3702274A5A396EA86FAAEC92CB675936D6F6D59E3A355F4D0F78C8C'
    'data6.dat' = '81DEC650BACB7D570D7352208DBB73EAD5D513B31A9C5D8AAE355A2150680E70'
    'data\font\anticcezannepro.otf' = 'BD505B1E18E9F3484011CE1014C0CF7FC73CC1338C790FA1AAB1A3027856638F'
    'data\font\tsukugopro-m.otf' = 'BD505B1E18E9F3484011CE1014C0CF7FC73CC1338C790FA1AAB1A3027856638F'
    'malie_kr.ini' = '97FC23AA552A07F4811BE9A2F14C4567B37C34B5D30B442D8B90D7A2ECF7CDEC'
}
foreach ($entry in $packageHashes.GetEnumerator()) {
    Assert-Hash (Join-Path $FilesRoot $entry.Key) $entry.Value
}

foreach ($name in @('data5.dat', 'data6.dat')) {
    $target = Join-Path $GameDir $name
    if ((Test-Path -LiteralPath $target -PathType Leaf) -and -not $AllowBackupExistingOverlays) {
        throw "$name 파일이 이미 있습니다. 기존 파일까지 백업하려면 -AllowBackupExistingOverlays를 명시적으로 사용하십시오."
    }
}

$timestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [Guid]::NewGuid().ToString('N')
$backupDir = Join-Path $BackupRoot $timestamp
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$tracked = @(
    'malie.exe', 'malie_fabula.exe', 'malie.ini', 'data5.dat', 'data6.dat',
    'data\font\anticcezannepro.otf', 'data\font\tsukugopro-m.otf'
)
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
    $malie_exePatches = @(
        [pscustomobject]@{ Offset = 0x2958A5; BeforeHex = '68 CC BA 76 00'; AfterHex = '68 58 38 72 00' }
        [pscustomobject]@{ Offset = 0x3635D8; BeforeHex = '51 00 75 00 69 00 63 00 6B 00 2E 00 00 00 00 00'; AfterHex = '35 D0 2E 00 00 00 00 00 00 00 00 00 00 00 00 00' }
        [pscustomobject]@{ Offset = 0x3635E8; BeforeHex = '20 00 41 00 75 00 74 00 6F 00 2E 00 00 00 00 00'; AfterHex = '20 00 90 C7 D9 B3 2E 00 00 00 00 00 00 00 00 00' }
    )
    Patch-Executable (Join-Path $GameDir 'malie.exe') $malie_exePatches $baseline['malie.exe'] '07CBB4AB77765C45344C6312A657FCD74A711B6C8F747F2295153BF621F8EE8E'
    $malie_fabula_exePatches = @(
        [pscustomobject]@{ Offset = 0x2970F5; BeforeHex = '68 5C DB 76 00'; AfterHex = '68 E8 58 72 00' }
        [pscustomobject]@{ Offset = 0x365268; BeforeHex = '51 00 75 00 69 00 63 00 6B 00 2E 00 00 00 00 00'; AfterHex = '35 D0 2E 00 00 00 00 00 00 00 00 00 00 00 00 00' }
        [pscustomobject]@{ Offset = 0x365278; BeforeHex = '20 00 41 00 75 00 74 00 6F 00 2E 00 00 00 00 00'; AfterHex = '20 00 90 C7 D9 B3 2E 00 00 00 00 00 00 00 00 00' }
    )
    Patch-Executable (Join-Path $GameDir 'malie_fabula.exe') $malie_fabula_exePatches $baseline['malie_fabula.exe'] '5335D430789AA0B8C84E16B30BE744F7D544D0D2F19E3D19B59A35F2F3BC365E'

    Install-VerifiedFile (Join-Path $FilesRoot 'malie_kr.ini') (Join-Path $GameDir 'malie.ini') $packageHashes['malie_kr.ini']
    Install-VerifiedFile (Join-Path $FilesRoot 'data5.dat') (Join-Path $GameDir 'data5.dat') $packageHashes['data5.dat']
    Install-VerifiedFile (Join-Path $FilesRoot 'data6.dat') (Join-Path $GameDir 'data6.dat') $packageHashes['data6.dat']
    $fontDir = Join-Path $GameDir 'data\font'
    New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
    Install-VerifiedFile (Join-Path $FilesRoot 'data\font\anticcezannepro.otf') (Join-Path $fontDir 'anticcezannepro.otf') $packageHashes['data\font\anticcezannepro.otf']
    Install-VerifiedFile (Join-Path $FilesRoot 'data\font\tsukugopro-m.otf') (Join-Path $fontDir 'tsukugopro-m.otf') $packageHashes['data\font\tsukugopro-m.otf']

    $installedHashes = [ordered]@{
        'malie.exe' = '07CBB4AB77765C45344C6312A657FCD74A711B6C8F747F2295153BF621F8EE8E'
        'malie_fabula.exe' = '5335D430789AA0B8C84E16B30BE744F7D544D0D2F19E3D19B59A35F2F3BC365E'
        'malie.ini' = $packageHashes['malie_kr.ini']
        'data5.dat' = $packageHashes['data5.dat']
        'data6.dat' = $packageHashes['data6.dat']
        'data\font\anticcezannepro.otf' = $packageHashes['data\font\anticcezannepro.otf']
        'data\font\tsukugopro-m.otf' = $packageHashes['data\font\tsukugopro-m.otf']
    }
    foreach ($entry in $installedHashes.GetEnumerator()) {
        Assert-Hash (Join-Path $GameDir $entry.Key) $entry.Value
    }
    $manifest = [ordered]@{
        schema = 'dies-irae-kr.install-manifest.v2'
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

Write-Host "Dies irae DX 한국어 패치 $ReleaseVersion 설치 완료"
Write-Host "게임: $GameDir"
Write-Host "백업: $backupDir"
Write-Host 'verify_ko.ps1을 실행한 뒤 malie.exe 또는 malie_fabula.exe를 시작하십시오.'
