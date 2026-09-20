[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [Parameter(Mandatory)][string]$SourceCommit
)

$ErrorActionPreference = 'Stop'
$installRoot = [IO.Path]::GetFullPath($Root)
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
$settings = Get-Content (Join-Path $PSScriptRoot 'settings.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$release = [string]$settings.release
if ($release -notmatch '^[0-9][a-zA-Z0-9._-]*$') { throw 'Invalid release directory name.' }
if ($SourceCommit -notmatch '^[a-fA-F0-9]{40}$') { throw 'SourceCommit must be a full Git commit hash.' }
$releaseRoot = Join-Path $installRoot "releases\$release"
$binary = Join-Path $releaseRoot 'opencode.exe'
$metadata = Get-Content (Join-Path $releaseRoot 'release.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ((Get-FileHash $binary -Algorithm SHA256).Hash -ne $metadata.sha256) { throw 'Release binary hash mismatch.' }

New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$stage = Join-Path $outputRoot ('stage-' + $release + '-' + [Guid]::NewGuid().ToString('N'))
$portableRoot = Join-Path $stage 'OpenCode'
New-Item -ItemType Directory -Path (Join-Path $portableRoot "releases\$release"), (Join-Path $portableRoot 'runtime') -Force | Out-Null
Copy-Item -LiteralPath $PSScriptRoot -Destination (Join-Path $portableRoot 'bairui') -Recurse
Copy-Item -LiteralPath $binary -Destination (Join-Path $portableRoot "releases\$release\opencode.exe")
$metadata.source | Add-Member -NotePropertyName commit -NotePropertyValue $SourceCommit -Force
$metadata.notes = 'Windows preview with embedded Web UI. See the included release guide for validation and limitations.'
$metadata | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $portableRoot "releases\$release\release.json") -Encoding UTF8

foreach ($tool in @('bun', 'node')) {
    Copy-Item -LiteralPath (Join-Path $installRoot "runtime\$tool") -Destination (Join-Path $portableRoot "runtime\$tool") -Recurse
}
$gitRoot = Join-Path $portableRoot 'runtime\git'
New-Item -ItemType Directory -Path $gitRoot -Force | Out-Null
foreach ($part in @('bin', 'cmd', 'dev', 'etc', 'mingw64', 'usr', 'git-bash.exe', 'git-cmd.exe', 'LICENSE.txt', 'ReleaseNotes.html')) {
    Copy-Item -LiteralPath (Join-Path $installRoot "runtime\git\$part") -Destination (Join-Path $gitRoot $part) -Recurse
}
foreach ($entry in @('启动BAIRUI.cmd', '启动BAIRUI终端.cmd', '停止BAIRUI.cmd')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $entry) -Destination (Join-Path $stage $entry)
}
$sourceRoot = Split-Path -Parent $PSScriptRoot
Copy-Item -LiteralPath (Join-Path $sourceRoot 'LICENSE') -Destination (Join-Path $stage 'LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $sourceRoot 'README.md') -Destination (Join-Path $stage 'README.md')
New-Item -ItemType Directory -Path (Join-Path $portableRoot 'docs') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $sourceRoot 'docs\bairui-release.md') -Destination (Join-Path $portableRoot 'docs\bairui-release.md')
& (Join-Path $portableRoot 'bairui\seal-release.ps1') -Root $portableRoot -Release $release
& (Join-Path $portableRoot 'bairui\verify-release.ps1') -Root $portableRoot

$zip = Join-Path $outputRoot "BAIRUI-$release-windows-x64-portable.zip"
if (Test-Path -LiteralPath $zip) { throw "Archive already exists: $zip" }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($stage, $zip, [IO.Compression.CompressionLevel]::Optimal, $false)
$checksum = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
"$checksum  $([IO.Path]::GetFileName($zip))" | Set-Content (Join-Path $outputRoot 'SHA256SUMS.txt') -Encoding ascii
Write-Output "Archive: $zip"
Write-Output "Clean staging directory: $stage"
Write-Output "SHA256: $checksum"
