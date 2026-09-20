[CmdletBinding()]
param([string]$Root)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent $PSScriptRoot }
. (Join-Path $PSScriptRoot 'launch-env.ps1') -Root $Root
. (Join-Path $PSScriptRoot 'instance-lock.ps1')
$bairuiLock = Read-BairuiInstanceLock
$bairuiListeners = @(Get-NetTCPConnection -ErrorAction Stop | Where-Object { $_.State -eq 'Listen' -and $_.LocalPort -eq $bairuiWebPort })
if ($bairuiListeners) {
    foreach ($bairuiProcessID in ($bairuiListeners.OwningProcess | Select-Object -Unique)) {
        $bairuiProcess = Get-Process -Id $bairuiProcessID -ErrorAction Stop
        if ($bairuiProcess.Path -ne $bairuiExecutable) { throw "Port $bairuiWebPort belongs to another program; nothing was stopped." }
    }
    $bairuiStoppedPids = @($bairuiListeners.OwningProcess | Select-Object -Unique)
    foreach ($bairuiProcessID in $bairuiStoppedPids) {
        Stop-Process -Id $bairuiProcessID -ErrorAction Stop
    }
    Remove-BairuiInstanceLock -ExpectedOwnerPids $bairuiStoppedPids
    Write-Output "BAIRUI Web stopped on port $bairuiWebPort. Active tasks were interrupted."
    return
}

if ($null -ne $bairuiLock -and (Test-BairuiLockOwner -LockState $bairuiLock)) {
    $bairuiOwnerPid = [int]$bairuiLock.ownerPid
    $bairuiStoppedPids = @($bairuiOwnerPid)

    if ([string]$bairuiLock.mode -eq 'TUI') {
        # TUI is attached to the caller's console and has no HTTP listener. Its
        # lock owner is the launcher PowerShell process, so stop only the
        # launcher tree when its command line proves it is this TUI entrypoint.
        $bairuiProcesses = @(Get-CimInstance Win32_Process -ErrorAction Stop)
        $bairuiOwnerRecord = $bairuiProcesses | Where-Object { [int]$_.ProcessId -eq $bairuiOwnerPid } | Select-Object -First 1
        if ($null -eq $bairuiOwnerRecord -or [string]$bairuiOwnerRecord.CommandLine -notmatch '(?i)bairui[\\/]start\.ps1.*-Mode\s+TUI') {
            throw "The BAIRUI TUI lock owner could not be identified safely (PID $bairuiOwnerPid). Nothing was stopped."
        }

        $bairuiTree = New-Object System.Collections.Generic.List[object]
        $bairuiQueue = New-Object System.Collections.Generic.Queue[int]
        $bairuiQueue.Enqueue($bairuiOwnerPid)
        while ($bairuiQueue.Count -gt 0) {
            $bairuiParentPid = $bairuiQueue.Dequeue()
            foreach ($bairuiChild in @($bairuiProcesses | Where-Object { [int]$_.ParentProcessId -eq $bairuiParentPid })) {
                if (-not ($bairuiTree.ProcessId -contains [int]$bairuiChild.ProcessId)) {
                    $bairuiTree.Add($bairuiChild)
                    $bairuiQueue.Enqueue([int]$bairuiChild.ProcessId)
                }
            }
        }
        $bairuiTuiExecutables = @($bairuiTree | Where-Object {
            [string]::Equals([string]$_.ExecutablePath, [string]$bairuiExecutable, [StringComparison]::OrdinalIgnoreCase)
        })
        if ($bairuiTuiExecutables.Count -eq 0) {
            throw "The BAIRUI TUI process was not found under its launcher (PID $bairuiOwnerPid). Nothing was stopped."
        }
        foreach ($bairuiChild in ($bairuiTree | Sort-Object { [int]$_.ParentProcessId } -Descending)) {
            if ([int]$bairuiChild.ProcessId -ne $PID) {
                Stop-Process -Id ([int]$bairuiChild.ProcessId) -Force -ErrorAction SilentlyContinue
                $bairuiStoppedPids += [int]$bairuiChild.ProcessId
            }
        }
        Stop-Process -Id $bairuiOwnerPid -Force -ErrorAction SilentlyContinue
        Remove-BairuiInstanceLock -ExpectedOwnerPids $bairuiStoppedPids
        Write-Output 'BAIRUI TUI stopped. Active tasks were interrupted.'
        return
    }

    $bairuiOwnerProcess = Get-Process -Id $bairuiOwnerPid -ErrorAction Stop
    if ($bairuiOwnerProcess.Path -ne $bairuiExecutable) { throw 'The BAIRUI lock owner is not the expected executable; nothing was stopped.' }
    Stop-Process -Id $bairuiOwnerPid -ErrorAction Stop
    Remove-BairuiInstanceLock -ExpectedOwnerPids @($bairuiOwnerPid)
    Write-Output 'BAIRUI process stopped before it opened its Web listener. Active tasks were interrupted.'
    return
}

if ($null -ne $bairuiLock) {
    Remove-BairuiInstanceLock
    Write-Output "BAIRUI is not running on port $bairuiWebPort. Removed a stale instance lock."
}
else {
    Write-Output "BAIRUI is not running on port $bairuiWebPort."
}
