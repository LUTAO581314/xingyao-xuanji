[CmdletBinding()]
param([string]$Root)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent $PSScriptRoot }
$bairuiInstallRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Root)
$bairuiExe = Join-Path $bairuiInstallRoot 'releases\1.18.31-bairui-prompt.1\opencode.exe'
$bairuiListeners = @(Get-NetTCPConnection -ErrorAction Stop | Where-Object { $_.State -eq 'Listen' -and $_.LocalPort -eq 4098 })
if (-not $bairuiListeners) { Write-Output 'BAIRUI is not running on port 4098.'; return }
foreach ($bairuiProcessID in ($bairuiListeners.OwningProcess | Select-Object -Unique)) {
    $bairuiProcess = Get-Process -Id $bairuiProcessID -ErrorAction Stop
    if ($bairuiProcess.Path -ne $bairuiExe) { throw 'Port 4098 belongs to another program; nothing was stopped.' }
}
foreach ($bairuiProcessID in ($bairuiListeners.OwningProcess | Select-Object -Unique)) {
    Stop-Process -Id $bairuiProcessID -ErrorAction Stop
}
Write-Output 'BAIRUI stopped. Active tasks were interrupted.'
