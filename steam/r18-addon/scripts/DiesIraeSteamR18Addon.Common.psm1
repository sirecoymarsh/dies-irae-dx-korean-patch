Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Config = [ordered]@{
    Schema = 'dies-irae-steam-r18-kr-addon.config.v1'
    ReleaseVersion = '1.0.0-steam-r18-addon'
    SteamAppId = '644540'
    SteamBuildId = '21665074'
    AaHashes = [ordered]@{
        'malie.exe' = 'FF105876B39458E54CA8C4C8E5231CE013FB2AC4D3554B8611BD98C85C88CC30'
        'data3.dat' = '0DEA33565F85BB2B3321A0B8FA34B57E066DDE3DBEA739D2E5EB3474D00A6968'
        'data4.cn.dat' = '8945DC46FF25983174C31A501CFE1D3874CEDF4E02E13C670F772E0532C8A7FE'
        'data5.dat' = 'B91EBA7FF3702274A5A396EA86FAAEC92CB675936D6F6D59E3A355F4D0F78C8C'
        'malie.ini' = '97FC23AA552A07F4811BE9A2F14C4567B37C34B5D30B442D8B90D7A2ECF7CDEC'
        'data\font\anticcezannepro.otf' = 'BD505B1E18E9F3484011CE1014C0CF7FC73CC1338C790FA1AAB1A3027856638F'
        'data\font\tsukugopro-m.otf' = 'BD505B1E18E9F3484011CE1014C0CF7FC73CC1338C790FA1AAB1A3027856638F'
        'steam_api.dll' = 'FE302B9CF000B5B56B8F48DF9A6737FC43B1C225DB91306E92C779CAE0D2908D'
        'steam_appid.txt' = '3B61CBF22ECC4AF4C59FEFC5175143A4C5A594CFAEECC3A7AFFC7F11808C7ACA'
        'as.ini' = '8E8EE181E1ED9F3F479690B0B743578EFD3A553B7A335D3E3666DDDFF39E8352'
    }
    OfficialZip = [ordered]@{
        Sha256 = '2D170EA430D30E5FDB21AA5659380E3A3920652FB6FE2E2BA431638401CF52AD'
        Data4Entry = 'r18_patch_20171226/data4.dat'
        ExeEntry = 'r18_patch_20171226/malie_fabula.exe'
    }
    R18Hashes = [ordered]@{
        'data4.dat' = '16A001365E7AE6D98BC30838EF3727AC4DA600AA5EC5F573C8475EF8A7D92C63'
        'malie_fabula.official.exe' = '7F8DD40212289F08F05EFE180B3C5138329980C82FE049ED7EBA57D5B1732CF1'
        'malie_fabula.exe' = '6A5E7DDD3FC2BEE77539F09F82F3F89C4116D32AB7E3480CF7E7153A168CF818'
        'data6.dat' = '81DEC650BACB7D570D7352208DBB73EAD5D513B31A9C5D8AAE355A2150680E70'
    }
}

function Get-AddonConfig { return $script:Config }

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
    return $leftRoot.StartsWith($rightRoot, [StringComparison]::OrdinalIgnoreCase) -or
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
    $targets = @(
        [IO.Path]::GetFullPath((Join-Path $Directory 'malie.exe')),
        [IO.Path]::GetFullPath((Join-Path $Directory 'malie_fabula.exe'))
    )
    foreach ($name in @('malie', 'malie_fabula')) {
        foreach ($process in @(Get-Process -Name $name -ErrorAction SilentlyContinue)) {
            try { $processPath = [IO.Path]::GetFullPath([string]$process.Path) } catch { continue }
            if ($targets -contains $processPath) {
                throw "게임 실행 파일이 사용 중입니다: $processPath"
            }
        }
    }
}

function Install-VerifiedFile([string]$Source, [string]$Destination, [string]$ExpectedHash) {
    Assert-Hash $Source $ExpectedHash
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    $incoming = "$Destination.krr18.incoming"
    if (Test-Path -LiteralPath $incoming -PathType Leaf) { Remove-Item -LiteralPath $incoming -Force }
    Copy-Item -LiteralPath $Source -Destination $incoming -Force
    Assert-Hash $incoming $ExpectedHash
    Move-Item -LiteralPath $incoming -Destination $Destination -Force
    Assert-Hash $Destination $ExpectedHash
}

function Restore-VerifiedFile([string]$Source, [string]$Destination, [string]$ExpectedHash) {
    Install-VerifiedFile $Source $Destination $ExpectedHash
}

function Find-OfficialR18Zip([string]$RequestedPath, [string]$PackageRoot) {
    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) { $candidates += $RequestedPath }
    $candidates += (Join-Path $PackageRoot 'dies_irae_r18_patch.zip')
    $downloads = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads\dies_irae_r18_patch.zip'
    $candidates += $downloads
    $seen = @{}
    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        $full = [IO.Path]::GetFullPath($candidate)
        if ($seen.ContainsKey($full)) { continue }
        $seen[$full] = $true
        if (Test-Path -LiteralPath $full -PathType Leaf) {
            $actual = Get-Sha256 $full
            if ($actual -eq $script:Config.OfficialZip.Sha256) { return $full }
            if (-not [string]::IsNullOrWhiteSpace($RequestedPath) -and
                $full -eq [IO.Path]::GetFullPath($RequestedPath)) {
                throw "지정한 R-18 패치 ZIP 해시가 다릅니다: $full`n실제: $actual"
            }
        }
    }
    if ([Environment]::UserInteractive -and [string]::IsNullOrWhiteSpace($RequestedPath)) {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object Windows.Forms.OpenFileDialog
            $dialog.Title = '공식 dies_irae_r18_patch.zip 선택'
            $dialog.Filter = 'Dies irae R-18 patch (dies_irae_r18_patch.zip)|dies_irae_r18_patch.zip|ZIP files (*.zip)|*.zip'
            $dialog.CheckFileExists = $true
            if ($dialog.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
                $selected = [IO.Path]::GetFullPath($dialog.FileName)
                Assert-Hash $selected $script:Config.OfficialZip.Sha256
                return $selected
            }
        } catch {
            if ($_.Exception.Message -like '*해시 불일치*') { throw }
        }
    }
    throw '공식 dies_irae_r18_patch.zip을 찾지 못했습니다. 파일을 패키지 폴더에 두거나 -R18Zip으로 지정하십시오.'
}

function Expand-VerifiedR18Zip([string]$ZipPath, [string]$Destination) {
    Assert-Hash $ZipPath $script:Config.OfficialZip.Sha256
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $files = @($archive.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) })
        $entryMap = @{}
        foreach ($entry in $files) {
            $normalized = ([string]$entry.FullName).Replace('\', '/')
            if ($normalized.StartsWith('/') -or $normalized -match '(^|/)\.\.(/|$)') {
                throw "ZIP에 안전하지 않은 경로가 있습니다: $normalized"
            }
            if ($entryMap.ContainsKey($normalized)) { throw "ZIP에 중복 항목이 있습니다: $normalized" }
            $entryMap[$normalized] = $entry
        }
        $expected = @($script:Config.OfficialZip.Data4Entry, $script:Config.OfficialZip.ExeEntry)
        if ($entryMap.Count -ne $expected.Count) {
            throw "공식 R-18 ZIP 파일 항목 수가 예상과 다릅니다: $($entryMap.Count)"
        }
        foreach ($name in $expected) {
            if (-not $entryMap.ContainsKey($name)) { throw "공식 R-18 ZIP 항목이 없습니다: $name" }
        }
        $data4 = Join-Path $Destination 'data4.dat'
        $exe = Join-Path $Destination 'malie_fabula.official.exe'
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entryMap[$script:Config.OfficialZip.Data4Entry], $data4, $true)
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entryMap[$script:Config.OfficialZip.ExeEntry], $exe, $true)
    } finally { $archive.Dispose() }
    Assert-Hash $data4 $script:Config.R18Hashes['data4.dat']
    Assert-Hash $exe $script:Config.R18Hashes['malie_fabula.official.exe']
    return [pscustomobject]@{ Data4=$data4; OfficialExe=$exe }
}

function Convert-HexToBytes([string]$Hex) {
    $clean = $Hex -replace '\s', ''
    if (($clean.Length % 2) -ne 0) { throw '잘못된 16진수 바이트열입니다.' }
    $bytes = New-Object byte[] ($clean.Length / 2)
    for ($i=0; $i -lt $bytes.Length; $i++) {
        $bytes[$i] = [Convert]::ToByte($clean.Substring($i*2,2),16)
    }
    return $bytes
}

function Set-ExactBytes([byte[]]$Data, [int]$Offset, [byte[]]$Before, [byte[]]$After, [string]$Label) {
    if ($Before.Length -ne $After.Length) { throw "$Label 패치 길이가 다릅니다." }
    if ($Offset -lt 0 -or $Offset + $Before.Length -gt $Data.Length) { throw "$Label 패치 범위가 잘못되었습니다." }
    for ($i=0; $i -lt $Before.Length; $i++) {
        if ($Data[$Offset+$i] -ne $Before[$i]) {
            throw ("{0} 패치 전 바이트 불일치: 0x{1:X}" -f $Label,($Offset+$i))
        }
    }
    [Array]::Copy($After,0,$Data,$Offset,$After.Length)
}

function New-PatchedR18Executable([string]$OfficialExe, [string]$OutputExe) {
    Assert-Hash $OfficialExe $script:Config.R18Hashes['malie_fabula.official.exe']
    [byte[]]$data = [IO.File]::ReadAllBytes($OfficialExe)
    Set-ExactBytes $data 2717184 `
        (Convert-HexToBytes '55 8B EC 56 57 68 4C DC 76 00 FF 75 08 E8 0E 14 00 00 8B F8 57 E8 16 00 00 00 57 8B F0 E8 BE 13 00 00 83 C4 10') `
        (Convert-HexToBytes '55 8B EC 56 57 68 D8 59 72 00 FF 75 08 E8 0E 14 00 00 8B F8 57 E8 16 00 00 00 57 8B F0 E8 BE 13 00 00 83 C4 10') `
        'UTF-8 translation.csv provider'
    Set-ExactBytes $data 3560792 `
        (Convert-HexToBytes '51 00 75 00 69 00 63 00 6B 00 2E 00 00 00 00 00') `
        (Convert-HexToBytes '35 D0 2E 00 00 00 00 00 00 00 00 00 00 00 00 00') `
        '퀵 저장 라벨'
    Set-ExactBytes $data 3560808 `
        (Convert-HexToBytes '20 00 41 00 75 00 74 00 6F 00 2E 00 00 00 00 00') `
        (Convert-HexToBytes '20 00 90 C7 D9 B3 2E 00 00 00 00 00 00 00 00 00') `
        '자동 저장 라벨'
    Set-ExactBytes $data 432 `
        (Convert-HexToBytes 'A7 E9 40 00') `
        (Convert-HexToBytes '39 AF 40 00') `
        'PE 체크섬'
    [IO.File]::WriteAllBytes($OutputExe,$data)
    Assert-Hash $OutputExe $script:Config.R18Hashes['malie_fabula.exe']
}

Export-ModuleMember -Function *

