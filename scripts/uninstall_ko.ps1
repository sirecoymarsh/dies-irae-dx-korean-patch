param(
    [Parameter(Mandatory=$true)]
    [string]$GameDir,
    [string]$StateRoot = '',
    [switch]$ForceRestore
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
    $StateRoot = Join-Path $localAppData 'DiesIraeDXKR'
}
$StateRoot = [IO.Path]::GetFullPath($StateRoot)
Assert-NoReparsePoint $StateRoot 'StateRoot'
Assert-NoReparsePoint $GameDir 'GameDir'
$GameStateRoot = Join-Path $StateRoot (Get-PathId $GameDir)
$ActiveManifest = Join-Path $GameStateRoot 'active_manifest.json'

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
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

if (-not (Test-Path -LiteralPath $ActiveManifest -PathType Leaf)) {
    throw "활성 패치 설치 상태를 찾을 수 없습니다: $ActiveManifest"
}
$manifest = Get-Content -LiteralPath $ActiveManifest -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-NoReparsePoint $ActiveManifest 'ActiveManifest'
if ([string]$manifest.schema -ne 'dies-irae-kr.install-manifest.v2') {
    throw '설치 기록 스키마가 일치하지 않습니다.'
}
$expectedTracked = @('malie.exe', 'malie_fabula.exe', 'malie.ini', 'data5.dat', 'data6.dat', 'data\font\anticcezannepro.otf', 'data\font\tsukugopro-m.otf')
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
if ([IO.Path]::GetFullPath([string]$manifest.gameStateRoot) -ne $GameStateRoot) {
    throw '설치 기록의 gameStateRoot가 일치하지 않습니다.'
}
$backupRoot = Join-Path $GameStateRoot 'backups'
$backupDir = [IO.Path]::GetFullPath([string]$manifest.backupDir)
$backupTrimChars = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
$backupRootFull = [IO.Path]::GetFullPath($backupRoot).TrimEnd($backupTrimChars)
$backupRootPrefix = $backupRootFull + [IO.Path]::DirectorySeparatorChar
if (-not $backupDir.StartsWith($backupRootPrefix, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Parent $backupDir) -ne $backupRootFull) {
    throw '백업 경로가 관리 범위를 벗어났습니다.'
}
Assert-NoReparsePoint $backupRoot 'BackupRoot'
Assert-NoReparsePoint $backupDir 'BackupDir'
$states = @($manifest.originalStates)
if ($states.Count -ne $expectedTracked.Count) { throw '원본 상태 기록 수가 일치하지 않습니다.' }
$seenStates = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($state in $states) {
    $relative = [string]$state.relativePath
    if ($expectedTracked -notcontains $relative -or -not $seenStates.Add($relative)) {
        throw '원본 상태 기록에 중복 또는 비허용 경로가 있습니다.'
    }
    [void](Get-SafeChildPath $GameDir $relative)
    if ([bool]$state.originalExists) {
        if ([string]$state.originalSha256 -notmatch '^[0-9A-Fa-f]{64}$') { throw '원본 SHA-256이 잘못되었습니다.' }
        $expectedBackup = Get-SafeChildPath $backupDir $relative
        if ([IO.Path]::GetFullPath([string]$state.backupPath) -ne $expectedBackup) { throw '백업 파일 경로가 일치하지 않습니다.' }
    } elseif (-not [string]::IsNullOrEmpty([string]$state.backupPath) -or -not [string]::IsNullOrEmpty([string]$state.originalSha256)) {
        throw '없었던 파일에 백업 기록이 있습니다.'
    }
}
if ([IO.Path]::GetFullPath([string]$manifest.gameDir) -ne $GameDir) {
    throw '설치 기록의 게임 경로와 현재 경로가 일치하지 않습니다.'
}
if ([IO.Path]::GetFullPath([string]$manifest.stateRoot) -ne $StateRoot) {
    throw '설치 기록의 상태 경로와 현재 -StateRoot가 일치하지 않습니다.'
}
Assert-GameStopped $GameDir
foreach ($property in $manifest.installedHashes.PSObject.Properties) {
    $target = Join-Path $GameDir $property.Name
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        if (-not $ForceRestore) {
            throw "설치된 패치 파일이 없습니다: $target`n이 상태를 버리고 복원하려면 -ForceRestore를 사용하십시오."
        }
    } else {
        $actual = Get-Sha256 $target
        if (($actual -ne ([string]$property.Value).ToUpperInvariant()) -and -not $ForceRestore) {
            throw "설치된 패치 파일이 설치 후 변경되었습니다: $target`n변경을 버리고 복원하려면 -ForceRestore를 사용하십시오."
        }
    }
}
# Verify the entire recovery set before making the first restoration write.
foreach ($state in $manifest.originalStates) {
    if ([bool]$state.originalExists) {
        $backup = [string]$state.backupPath
        if (-not (Test-Path -LiteralPath $backup -PathType Leaf)) {
            throw "백업 파일이 없습니다: $backup"
        }
        if ((Get-Sha256 $backup) -ne ([string]$state.originalSha256).ToUpperInvariant()) {
            throw "백업 파일 해시가 기록과 다릅니다: $backup"
        }
    }
}
foreach ($state in $manifest.originalStates) {
    $target = Join-Path $GameDir ([string]$state.relativePath)
    if ([bool]$state.originalExists) {
        $backup = [string]$state.backupPath
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        $incoming = $target + '.krpatch.restore'
        if (Test-Path -LiteralPath $incoming -PathType Leaf) {
            Remove-Item -LiteralPath $incoming -Force
        }
        Copy-Item -LiteralPath $backup -Destination $incoming -Force
        if ((Get-Sha256 $incoming) -ne ([string]$state.originalSha256).ToUpperInvariant()) {
            throw "복원 임시 파일 해시가 기록과 다릅니다: $incoming"
        }
        Move-Item -LiteralPath $incoming -Destination $target -Force
        if ((Get-Sha256 $target) -ne ([string]$state.originalSha256).ToUpperInvariant()) {
            throw "복원된 파일 해시가 기록과 다릅니다: $target"
        }
    } elseif (Test-Path -LiteralPath $target -PathType Leaf) {
        Remove-Item -LiteralPath $target -Force
    }
}
Remove-Item -LiteralPath $ActiveManifest -Force
$marker = Join-Path ([string]$manifest.backupDir) 'uninstalled.txt'
[IO.File]::WriteAllText($marker, ([DateTime]::UtcNow.ToString('o') + "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host '원래 설치 전 상태로 복원했습니다.'
Write-Host "백업 기록 보관 위치: $($manifest.backupDir)"
