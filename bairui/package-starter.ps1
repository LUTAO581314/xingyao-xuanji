[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$output = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $output -Force | Out-Null
$metadata = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'environment-release.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$name = "BAIRUI-$($metadata.release)-windows-x64-online-starter.zip"
$destination = Join-Path $output $name
if (Test-Path -LiteralPath $destination) { throw "Archive already exists: $destination" }
$stage = Join-Path $output ('starter-' + [Guid]::NewGuid().ToString('N'))
$scripts = Join-Path $stage 'OpenCode\bairui'
New-Item -ItemType Directory -Path $scripts -Force | Out-Null
foreach ($file in @('bairui.cmd', 'cli.ps1', 'env.ps1', 'environment.ps1', 'environment-release.json', 'desktop-start.ps1', 'instance-lock.ps1', 'launch-env.ps1', 'settings.json', 'start.ps1', 'stop.ps1', 'seal-release.ps1', 'verify-release.ps1')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $scripts $file)
}
foreach ($file in @('启动BAIRUI.cmd', '启动BAIRUI终端.cmd', '停止BAIRUI.cmd', '开始使用.txt')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $stage $file)
}
Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) 'LICENSE') -Destination (Join-Path $stage 'LICENSE.txt')
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$zip = [IO.Compression.ZipFile]::Open($destination, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem -LiteralPath $stage -Recurse -File) {
        $entryName = $file.FullName.Substring($stage.Length + 1).Replace('\', '/')
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entryName, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
}
finally { $zip.Dispose() }
$hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $name" | Set-Content -LiteralPath ($destination + '.sha256') -Encoding ascii
Write-Output "Archive: $destination"
Write-Output "Staging: $stage"
Write-Output "SHA256: $hash"
