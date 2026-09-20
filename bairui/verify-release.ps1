[CmdletBinding()]
param(
    [string]$Root,
    [string]$ManifestPath,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}
$bairuiInstallRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Root)
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $bairuiInstallRoot 'bairui\bairui-integrity.json'
}
$ManifestPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ManifestPath)

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "BAIRUI integrity manifest is missing: $ManifestPath. Run seal-release.ps1 before verification."
}
$bairuiManifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($bairuiManifest.product -ne 'BAIRUI') {
    throw "Unexpected integrity manifest product: $($bairuiManifest.product)"
}
if ($bairuiManifest.schema -ne 1 -or $bairuiManifest.hashAlgorithm -ne 'SHA256') {
    throw 'Unsupported BAIRUI integrity manifest schema or hash algorithm.'
}
if ($null -eq $bairuiManifest.files -or $bairuiManifest.files.Count -eq 0) {
    throw 'BAIRUI integrity manifest contains no files.'
}

$bairuiRootPrefix = ([IO.Path]::GetFullPath($bairuiInstallRoot)).TrimEnd('\') + '\'
$bairuiFailures = @()
foreach ($bairuiEntry in $bairuiManifest.files) {
    if ($bairuiEntry.path -isnot [string] -or [string]::IsNullOrWhiteSpace($bairuiEntry.path)) {
        $bairuiFailures += 'Manifest entry has no path.'
        continue
    }
    $bairuiRelativePath = $bairuiEntry.path -replace '/', '\'
    try {
        $bairuiAbsolutePath = [IO.Path]::GetFullPath((Join-Path $bairuiInstallRoot $bairuiRelativePath))
    }
    catch {
        $bairuiFailures += "Invalid path: $($bairuiEntry.path)"
        continue
    }
    if (-not $bairuiAbsolutePath.StartsWith($bairuiRootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        $bairuiFailures += "Path escapes BAIRUI root: $($bairuiEntry.path)"
        continue
    }
    if (-not (Test-Path -LiteralPath $bairuiAbsolutePath -PathType Leaf)) {
        $bairuiFailures += "Missing: $($bairuiEntry.path)"
        continue
    }
    $bairuiHash = (Get-FileHash -LiteralPath $bairuiAbsolutePath -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($bairuiHash -ne ([string]$bairuiEntry.sha256).ToUpperInvariant()) {
        $bairuiFailures += "Hash mismatch: $($bairuiEntry.path)"
        continue
    }
    if ($null -ne $bairuiEntry.bytes -and (Get-Item -LiteralPath $bairuiAbsolutePath).Length -ne [int64]$bairuiEntry.bytes) {
        $bairuiFailures += "Size mismatch: $($bairuiEntry.path)"
    }
}

if ($bairuiFailures.Count -gt 0) {
    $bairuiFailureText = $bairuiFailures -join [Environment]::NewLine
    throw "BAIRUI integrity verification failed:$([Environment]::NewLine)$bairuiFailureText"
}

if (-not $Quiet) {
    Write-Output "BAIRUI integrity verified: $($bairuiManifest.version)"
    Write-Output "Checked files: $($bairuiManifest.files.Count)"
}
