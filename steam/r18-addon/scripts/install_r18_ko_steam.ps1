param(
    [string]$GameDir = '',
    [string]$R18Zip = '',
    [string]$StateRoot = '',
    [switch]$AllowBackupExistingR18Files
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$PackageRoot = [IO.Path]::GetFullPath((Split-Path -Parent $MyInvocation.MyCommand.Path))
Import-Module (Join-Path $PackageRoot 'DiesIraeSteamR18Addon.Common.psm1') -Force
$config = Get-AddonConfig
$FilesRoot = Join-Path $PackageRoot 'files'

if ([string]::IsNullOrWhiteSpace($GameDir)) { $GameDir = Find-SteamGameDir }
$GameDir = [IO.Path]::GetFullPath($GameDir)
if ([string]::IsNullOrWhiteSpace($StateRoot)) {
    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    if ([string]::IsNullOrWhiteSpace($localAppData)) {
        throw 'LocalApplicationData를 확인할 수 없습니다. -StateRoot를 지정하십시오.'
    }
    $StateRoot = Join-Path $localAppData 'DiesIraeSteamKRR18'
}
$StateRoot = [IO.Path]::GetFullPath($StateRoot)

if (-not (Test-Path -LiteralPath $GameDir -PathType Container)) { throw "게임 폴더가 없습니다: $GameDir" }
if ((Test-PathOverlap $StateRoot $GameDir) -or (Test-PathOverlap $StateRoot $PackageRoot)) {
    throw '-StateRoot는 게임 또는 패키지 경로와 겹치지 않아야 합니다.'
}
foreach ($path in @($PackageRoot,$FilesRoot,$GameDir,$StateRoot)) { Assert-NoReparsePoint $path '관리' }

$tracked = @('data4.dat','malie_fabula.exe','data6.dat')
foreach ($relative in @($tracked + @($config.AaHashes.Keys))) {
    [void](Get-SafeChildPath $GameDir ([string]$relative))
}
Assert-GameStopped $GameDir

$gameStateRoot = Join-Path $StateRoot (Get-PathId $GameDir)
$backupRoot = Join-Path $gameStateRoot 'backups'
$activeManifest = Join-Path $gameStateRoot 'active_manifest.json'
if (Test-Path -LiteralPath $activeManifest -PathType Leaf) {
    throw "이미 활성화된 R-18 애드온 설치 상태가 있습니다: $activeManifest"
}

# 기존 Steam 한국어패치 1.0.3-steam-aa4와 플랫폼 파일이 그대로인지 먼저 확인한다.
foreach ($entry in $config.AaHashes.GetEnumerator()) {
    Assert-Hash (Join-Path $GameDir $entry.Key) $entry.Value
}
Assert-Hash (Join-Path $FilesRoot 'data6.dat') $config.R18Hashes['data6.dat']
$officialZip = Find-OfficialR18Zip $R18Zip $PackageRoot

$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char[]]@('\','/'))
$tempRoot = Join-Path $tempParent ('dies-irae-steam-r18-install-' + [Guid]::NewGuid().ToString('N'))
$tempFull = [IO.Path]::GetFullPath($tempRoot)
if (-not $tempFull.StartsWith($tempParent + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
    throw '임시 작업 경로가 시스템 임시 폴더를 벗어났습니다.'
}
New-Item -ItemType Directory -Force -Path $tempFull | Out-Null

$states = @()
$backupDir = $null
try {
    $expanded = Expand-VerifiedR18Zip $officialZip (Join-Path $tempFull 'official')
    $patchedExe = Join-Path $tempFull 'malie_fabula.exe'
    New-PatchedR18Executable $expanded.OfficialExe $patchedExe

    # 알려진 공식/한국어 상태는 자동 보존한다. 그 밖의 기존 파일은 명시적 승인이 필요하다.
    $recognized = @{
        'data4.dat' = @($config.R18Hashes['data4.dat'])
        'malie_fabula.exe' = @($config.R18Hashes['malie_fabula.official.exe'],$config.R18Hashes['malie_fabula.exe'])
        'data6.dat' = @($config.R18Hashes['data6.dat'])
    }
    foreach ($relative in $tracked) {
        $target = Join-Path $GameDir $relative
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { continue }
        $actual = Get-Sha256 $target
        if (($recognized[$relative] -notcontains $actual) -and -not $AllowBackupExistingR18Files) {
            throw "알 수 없는 기존 R-18 파일이 있습니다: $target`n해시: $actual`n백업 후 교체하려면 -AllowBackupExistingR18Files를 명시하십시오."
        }
    }

    $timestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [Guid]::NewGuid().ToString('N')
    $backupDir = Join-Path $backupRoot $timestamp
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    foreach ($relative in $tracked) {
        $target = Join-Path $GameDir $relative
        $exists = Test-Path -LiteralPath $target -PathType Leaf
        $state = [ordered]@{
            relativePath=$relative; originalExists=[bool]$exists
            originalSha256=$null; backupPath=$null
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
        Install-VerifiedFile $expanded.Data4 (Join-Path $GameDir 'data4.dat') $config.R18Hashes['data4.dat']
        Install-VerifiedFile $patchedExe (Join-Path $GameDir 'malie_fabula.exe') $config.R18Hashes['malie_fabula.exe']
        Install-VerifiedFile (Join-Path $FilesRoot 'data6.dat') (Join-Path $GameDir 'data6.dat') $config.R18Hashes['data6.dat']

        $installedHashes = [ordered]@{
            'data4.dat' = $config.R18Hashes['data4.dat']
            'malie_fabula.exe' = $config.R18Hashes['malie_fabula.exe']
            'data6.dat' = $config.R18Hashes['data6.dat']
        }
        foreach ($entry in $installedHashes.GetEnumerator()) {
            Assert-Hash (Join-Path $GameDir $entry.Key) $entry.Value
        }
        foreach ($entry in $config.AaHashes.GetEnumerator()) {
            Assert-Hash (Join-Path $GameDir $entry.Key) $entry.Value
        }

        $manifest = [ordered]@{
            schema='dies-irae-steam-r18-kr.install-manifest.v1'
            releaseVersion=$config.ReleaseVersion
            installedUtc=[DateTime]::UtcNow.ToString('o')
            gameDir=$GameDir; stateRoot=$StateRoot; gameStateRoot=$gameStateRoot
            backupDir=$backupDir
            officialZipSha256=$config.OfficialZip.Sha256
            aaRequiredHashes=$config.AaHashes
            originalStates=$states
            installedHashes=$installedHashes
        }
        $json = $manifest | ConvertTo-Json -Depth 12
        [IO.File]::WriteAllText((Join-Path $backupDir 'install_manifest.json'),$json,[Text.UTF8Encoding]::new($false))
        New-Item -ItemType Directory -Force -Path $gameStateRoot | Out-Null
        $manifestIncoming = "$activeManifest.incoming"
        [IO.File]::WriteAllText($manifestIncoming,$json,[Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $manifestIncoming -Destination $activeManifest -Force
    } catch {
        foreach ($state in $states) {
            $target = Join-Path $GameDir ([string]$state.relativePath)
            $incoming = "$target.krr18.incoming"
            if (Test-Path -LiteralPath $incoming -PathType Leaf) { Remove-Item -LiteralPath $incoming -Force }
            if ([bool]$state.originalExists) {
                Restore-VerifiedFile ([string]$state.backupPath) $target ([string]$state.originalSha256)
            } elseif (Test-Path -LiteralPath $target -PathType Leaf) {
                Remove-Item -LiteralPath $target -Force
            }
        }
        throw
    }
} finally {
    if (Test-Path -LiteralPath $tempFull -PathType Container) {
        $resolvedTemp = [IO.Path]::GetFullPath($tempFull)
        if (-not $resolvedTemp.StartsWith($tempParent + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
            throw '임시 폴더 정리 대상이 시스템 임시 폴더를 벗어났습니다.'
        }
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}

Write-Host "Dies irae Steam R-18 한국어 애드온 $($config.ReleaseVersion) 설치 완료"
Write-Host "게임: $GameDir"
Write-Host "실행 파일: $(Join-Path $GameDir 'malie_fabula.exe')"
Write-Host "백업: $backupDir"
Write-Host '2_R18_한국어_실행.cmd 또는 launch_r18_ko_steam.ps1을 사용하십시오.'
