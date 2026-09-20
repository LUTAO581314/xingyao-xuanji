[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ArchivePath,
    [Parameter(Mandatory)][string]$TestDirectory
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'environment.ps1')
$testRoot = [IO.Path]::GetFullPath($TestDirectory)
if (Test-Path -LiteralPath $testRoot) { throw 'Choose a new, empty test directory.' }
New-Item -ItemType Directory -Path (Join-Path $testRoot 'bairui'), (Join-Path $testRoot 'data'), (Join-Path $testRoot 'config') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'settings.json') -Destination (Join-Path $testRoot 'bairui\settings.json')
. (Join-Path $PSScriptRoot 'env.ps1') -Root $testRoot
$sentinel = Join-Path $testRoot 'data\history-do-not-change.txt'
$config = Join-Path $testRoot 'config\user-settings.json'
[IO.File]::WriteAllText($sentinel, 'Keep my history')
[IO.File]::WriteAllText($config, '{"keep":true}')
$hashes = @((Get-FileHash -LiteralPath $sentinel).Hash, (Get-FileHash -LiteralPath $config).Hash)
if (@(Get-BairuiEnvironmentIssues -Root $testRoot).Count -ne 4) { throw 'Missing components were not detected.' }
Write-Host 'PASS: detects all four missing components.'

$failed = $false
try { Assert-BairuiEnvironment -Root $testRoot }
catch { $failed = $_.Exception.Message.Contains('启动BAIRUI.cmd') }
if (-not $failed) { throw 'Noninteractive check must provide an actionable error.' }
Write-Host 'PASS: noninteractive launch explains recovery without hanging.'

$badArchive = Join-Path $testRoot 'runtime\temp\bad.zip'
[IO.File]::WriteAllText($badArchive, 'Not the published archive')
$failed = $false
try { Repair-BairuiEnvironment -Root $testRoot -ArchivePath $badArchive }
catch { $failed = $_.Exception.Message.Contains('校验失败') }
if (-not $failed -or (Test-Path (Join-Path $testRoot 'runtime\bun\bun.exe'))) { throw 'Unverified archive must not install files.' }
Write-Host 'PASS: invalid archive is rejected before installation.'

$lock = [IO.File]::Open((Join-Path $testRoot 'runtime\environment-repair.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
$failed = $false
try { Repair-BairuiEnvironment -Root $testRoot -ArchivePath $ArchivePath }
catch { $failed = $_.Exception.Message.Contains('另一个 BAIRUI') }
finally { $lock.Dispose() }
if (-not $failed) { throw 'Concurrent repair was not blocked.' }
Write-Host 'PASS: concurrent repair is blocked.'

Repair-BairuiEnvironment -Root $testRoot -ArchivePath $ArchivePath
if (@(Get-BairuiEnvironmentIssues -Root $testRoot).Count -ne 0) { throw 'Recovered runtime did not pass checks.' }
if ((Get-FileHash -LiteralPath $sentinel).Hash -ne $hashes[0] -or (Get-FileHash -LiteralPath $config).Hash -ne $hashes[1]) { throw 'User data changed.' }
Write-Host 'PASS: real release archive repairs all components and preserves data/config.'

$extra = Join-Path $testRoot 'runtime\bun\user-extra.txt'
[IO.File]::WriteAllText($extra, 'Keep my extra file')
$bun = Join-Path $testRoot 'runtime\bun\bun.exe'
[IO.File]::WriteAllBytes($bun, @())
if (@(Get-BairuiEnvironmentIssues -Root $testRoot).id -ne 'bun') { throw 'Damaged executable was not isolated.' }
Repair-BairuiEnvironment -Root $testRoot -ArchivePath $ArchivePath
if ([IO.File]::ReadAllText($extra) -ne 'Keep my extra file') { throw 'Extra component file was removed.' }
Write-Host 'PASS: repairs a damaged component and preserves additional files.'

'["bun"]' | Set-Content -LiteralPath (Join-Path $testRoot 'runtime\environment-repair.pending.json') -Encoding UTF8
if (@(Get-BairuiEnvironmentIssues -Root $testRoot).id -ne 'bun') { throw 'Interrupted repair marker was not detected.' }
Repair-BairuiEnvironment -Root $testRoot -ArchivePath $ArchivePath
Assert-BairuiEnvironment -Root $testRoot
Write-Host 'PASS: interrupted repairs retry successfully; healthy check needs no network.'
$pendingPath = Join-Path $testRoot 'runtime\environment-repair.pending.json'
foreach ($brokenMarker in @('{', '')) {
    [IO.File]::WriteAllText($pendingPath, $brokenMarker)
    if (@(Get-BairuiEnvironmentIssues -Root $testRoot).Count -ne 4) { throw 'Broken repair marker must remain recoverable.' }
}
Remove-Item -LiteralPath $pendingPath
Write-Host 'PASS: truncated and empty interruption markers remain recoverable.'
Write-Host "Environment verification complete. Disposable fixture: $testRoot"
