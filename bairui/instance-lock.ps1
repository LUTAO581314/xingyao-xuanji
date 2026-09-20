[CmdletBinding()]
param()

# The lock is a small, atomic marker rather than a named mutex. Web mode
# returns after starting the server, so the marker must outlive this launcher
# process. The owner PID and process start time make stale markers removable
# without trusting a recycled Windows PID.

function Get-BairuiProcessSignature {
    param([int]$ProcessId)

    try {
        $bairuiProcess = Get-Process -Id $ProcessId -ErrorAction Stop
        $bairuiStartTime = $bairuiProcess.StartTime.ToUniversalTime().ToString('o')
        return [pscustomobject]@{
            Process = $bairuiProcess
            StartTime = $bairuiStartTime
            Path = $bairuiProcess.Path
        }
    }
    catch {
        return $null
    }
}

function Read-BairuiInstanceLock {
    if (-not (Test-Path -LiteralPath $bairuiLockPath -PathType Leaf)) { return $null }
    try {
        return Get-Content -LiteralPath $bairuiLockPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        # A truncated marker is stale. The next acquisition can replace it.
        return $null
    }
}

function Test-BairuiLockOwner {
    param([object]$LockState)

    if ($null -eq $LockState -or $null -eq $LockState.ownerPid -or $null -eq $LockState.ownerStartTime) {
        return $false
    }
    $bairuiSignature = Get-BairuiProcessSignature -ProcessId ([int]$LockState.ownerPid)
    if ($null -eq $bairuiSignature) { return $false }
    if (-not [string]::Equals(
            $bairuiSignature.StartTime,
            [string]$LockState.ownerStartTime,
            [StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }
    if ($LockState.mode -eq 'Web' -and
        -not [string]::Equals([string]$bairuiSignature.Path, [string]$bairuiExecutable, [StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }
    return $true
}

function Write-BairuiInstanceLock {
    param(
        [ValidateSet('Web', 'TUI')]
        [string]$Mode,
        [int]$OwnerPid
    )

    $bairuiSignature = Get-BairuiProcessSignature -ProcessId $OwnerPid
    if ($null -eq $bairuiSignature) {
        throw "Cannot inspect BAIRUI lock owner process $OwnerPid."
    }
    $bairuiLockState = [ordered]@{
        product = 'BAIRUI'
        mode = $Mode
        ownerPid = $OwnerPid
        ownerStartTime = $bairuiSignature.StartTime
        executable = $bairuiExecutable
        port = [int]$bairuiWebPort
        createdUtc = [DateTime]::UtcNow.ToString('o')
    }
    $bairuiJson = $bairuiLockState | ConvertTo-Json -Depth 4
    $bairuiUtf8 = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($bairuiLockPath, $bairuiJson, $bairuiUtf8)
}

function Acquire-BairuiInstanceLock {
    param(
        [ValidateSet('Web', 'TUI')]
        [string]$Mode,
        [int]$OwnerPid = $PID
    )

    New-Item -ItemType Directory -Path (Split-Path -Parent $bairuiLockPath) -Force -ErrorAction Stop | Out-Null
    $bairuiExisting = Read-BairuiInstanceLock
    if ($null -ne $bairuiExisting -and (Test-BairuiLockOwner -LockState $bairuiExisting)) {
        if ($Mode -eq 'Web' -and [string]$bairuiExisting.mode -eq 'Web') {
            # Web start is intentionally idempotent. The caller still verifies
            # the listener and portable paths before opening the browser.
            return $false
        }
        throw "BAIRUI is already running in $($bairuiExisting.mode) mode (PID $($bairuiExisting.ownerPid)). Stop it before starting $Mode mode."
    }
    # CreateNew closes the race where two launchers inspect a missing marker at
    # the same time. A stale marker is removed only after a second owner check;
    # an active marker is never removed by a competing launcher.
    if (Test-Path -LiteralPath $bairuiLockPath -PathType Leaf) {
        $bairuiRecheck = Read-BairuiInstanceLock
        if ($null -ne $bairuiRecheck -and (Test-BairuiLockOwner -LockState $bairuiRecheck)) {
            throw "Another BAIRUI launcher acquired the instance lock. Try again after it finishes starting."
        }
        Remove-Item -LiteralPath $bairuiLockPath -Force -ErrorAction Stop
    }

    # The winner writes the complete marker before releasing the file handle.
    $bairuiStream = $null
    try {
        $bairuiStream = [IO.File]::Open($bairuiLockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $bairuiSignature = Get-BairuiProcessSignature -ProcessId $OwnerPid
        if ($null -eq $bairuiSignature) { throw "Cannot inspect BAIRUI lock owner process $OwnerPid." }
        $bairuiLockState = [ordered]@{
            product = 'BAIRUI'
            mode = $Mode
            ownerPid = $OwnerPid
            ownerStartTime = $bairuiSignature.StartTime
            executable = $bairuiExecutable
            port = [int]$bairuiWebPort
            createdUtc = [DateTime]::UtcNow.ToString('o')
        }
        $bairuiBytes = [Text.Encoding]::UTF8.GetBytes(($bairuiLockState | ConvertTo-Json -Depth 4))
        $bairuiStream.Write($bairuiBytes, 0, $bairuiBytes.Length)
    }
    catch [IO.IOException] {
        throw 'Another BAIRUI launcher acquired the instance lock. Try again after it finishes starting.'
    }
    finally {
        if ($null -ne $bairuiStream) { $bairuiStream.Dispose() }
    }
    return $true
}

function Update-BairuiInstanceLockOwner {
    param([int]$OwnerPid)
    $bairuiExisting = Read-BairuiInstanceLock
    if ($null -eq $bairuiExisting) { throw 'BAIRUI instance lock is missing while updating its owner.' }
    Write-BairuiInstanceLock -Mode ([string]$bairuiExisting.mode) -OwnerPid $OwnerPid
}

function Remove-BairuiInstanceLock {
    param([int[]]$ExpectedOwnerPids)
    $bairuiExisting = Read-BairuiInstanceLock
    if ($null -eq $bairuiExisting) { return }
    if ($ExpectedOwnerPids -and ($ExpectedOwnerPids -notcontains [int]$bairuiExisting.ownerPid)) { return }
    Remove-Item -LiteralPath $bairuiLockPath -Force -ErrorAction SilentlyContinue
}
