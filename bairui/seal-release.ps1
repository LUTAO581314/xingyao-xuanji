[CmdletBinding()]
param(
    [string]$Root,
    [string]$Release,
    [switch]$ReadOnly,
    [switch]$Unseal
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}
$bairuiInstallRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Root)
if (-not (Test-Path -LiteralPath $bairuiInstallRoot -PathType Container)) {
    throw "BAIRUI root directory does not exist: $bairuiInstallRoot"
}

$bairuiSettingsPath = Join-Path $PSScriptRoot 'settings.json'
if ([string]::IsNullOrWhiteSpace($Release)) {
    if (-not (Test-Path -LiteralPath $bairuiSettingsPath -PathType Leaf)) {
        throw "BAIRUI settings are missing: $bairuiSettingsPath"
    }
    $bairuiSettings = Get-Content -LiteralPath $bairuiSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $Release = [string]$bairuiSettings.release
}
if ([string]::IsNullOrWhiteSpace($Release) -or $Release -notmatch '^[0-9][a-zA-Z0-9._-]*$') {
    throw 'Release must be a directory name such as 1.18.31-bairui-brand.1.'
}

$bairuiReleaseRoot = Join-Path $bairuiInstallRoot ('releases\' + $Release)
if (-not (Test-Path -LiteralPath $bairuiReleaseRoot -PathType Container)) {
    throw "BAIRUI release directory does not exist: $bairuiReleaseRoot"
}

# Keep the list deliberately small: these are the executable and launch
# boundary files that define a portable release. Runtime data is mutable and
# is intentionally excluded from the integrity snapshot.
$bairuiRelativeFiles = @(
    "releases/$Release/opencode.exe",
    "releases/$Release/release.json",
    'bairui/bairui.cmd',
    'bairui/cli.ps1',
    'bairui/env.ps1',
    'bairui/environment.ps1',
    'bairui/environment-release.json',
    'bairui/desktop-start.ps1',
    'bairui/instance-lock.ps1',
    'bairui/launch-env.ps1',
    'bairui/settings.json',
    'bairui/start.ps1',
    'bairui/stop.ps1'
)

$bairuiFiles = @()
foreach ($bairuiRelativePath in $bairuiRelativeFiles) {
    $bairuiAbsolutePath = Join-Path $bairuiInstallRoot ($bairuiRelativePath -replace '/', '\')
    if (-not (Test-Path -LiteralPath $bairuiAbsolutePath -PathType Leaf)) {
        throw "Required integrity file is missing: $bairuiAbsolutePath"
    }
    $bairuiHash = Get-FileHash -LiteralPath $bairuiAbsolutePath -Algorithm SHA256
    $bairuiFiles += [ordered]@{
        path = $bairuiRelativePath
        sha256 = $bairuiHash.Hash.ToUpperInvariant()
        bytes = (Get-Item -LiteralPath $bairuiAbsolutePath).Length
    }
}

$bairuiManifestPath = Join-Path $bairuiInstallRoot 'bairui\bairui-integrity.json'

if ($ReadOnly -and $Unseal) {
    throw 'Choose either -ReadOnly or -Unseal, not both.'
}

if ($Unseal) {
    foreach ($bairuiRelativePath in ($bairuiRelativeFiles + @('bairui/bairui-integrity.json'))) {
        $bairuiAbsolutePath = Join-Path $bairuiInstallRoot ($bairuiRelativePath -replace '/', '\')
        if (Test-Path -LiteralPath $bairuiAbsolutePath -PathType Leaf) {
            Set-ItemProperty -LiteralPath $bairuiAbsolutePath -Name IsReadOnly -Value $false
        }
    }
    Write-Output 'BAIRUI release and launcher files are writable again.'
    return
}

$bairuiManifest = [ordered]@{
    product = 'BAIRUI'
    schema = 1
    version = $Release
    hashAlgorithm = 'SHA256'
    generatedAtUtc = [DateTime]::UtcNow.ToString('o')
    files = $bairuiFiles
}
$bairuiManifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $bairuiManifestPath -Encoding UTF8

if ($ReadOnly) {
    foreach ($bairuiRelativePath in ($bairuiRelativeFiles + @('bairui/bairui-integrity.json'))) {
        $bairuiAbsolutePath = Join-Path $bairuiInstallRoot ($bairuiRelativePath -replace '/', '\')
        if (Test-Path -LiteralPath $bairuiAbsolutePath -PathType Leaf) {
            Set-ItemProperty -LiteralPath $bairuiAbsolutePath -Name IsReadOnly -Value $true
        }
    }
}

Write-Output "BAIRUI integrity manifest written: $bairuiManifestPath"
Write-Output "Protected files: $($bairuiRelativeFiles.Count)"
if ($ReadOnly) {
    Write-Output 'Release and launcher files were marked read-only. Run seal-release.ps1 -Unseal before updating.'
}
