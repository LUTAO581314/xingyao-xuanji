[CmdletBinding()]
param(
    [string]$Root,
    [ValidateSet('Web', 'TUI')]
    [string]$Mode = 'Web',
    [string]$Project,
    [switch]$NoBrowser,
    [switch]$Interactive
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent $PSScriptRoot }
# Prepare portable temporary paths before probing or repairing any executables.
. (Join-Path $PSScriptRoot 'env.ps1') -Root $Root
. (Join-Path $PSScriptRoot 'environment.ps1')
Assert-BairuiEnvironment -Root $Root -Interactive:$Interactive
. (Join-Path $PSScriptRoot 'launch-env.ps1') -Root $Root
. (Join-Path $PSScriptRoot 'instance-lock.ps1')

if ([string]::IsNullOrWhiteSpace($Project)) {
    $Project = [IO.Path]::GetPathRoot($bairuiInstallRoot)
}
$bairuiProjectPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Project)
if ([IO.Path]::GetPathRoot($bairuiProjectPath) -ne [IO.Path]::GetPathRoot($bairuiInstallRoot)) {
    throw 'The project directory must be on the same drive as the portable installation.'
}
if (-not (Test-Path -LiteralPath $bairuiProjectPath -PathType Container)) {
    if (Test-Path -LiteralPath $bairuiProjectPath) {
        throw "The project path is not a directory: $bairuiProjectPath"
    }
    New-Item -ItemType Directory -Path $bairuiProjectPath -ErrorAction Stop | Out-Null
}

function Get-BairuiListener {
    @(Get-NetTCPConnection -ErrorAction Stop | Where-Object { $_.State -eq 'Listen' -and $_.LocalPort -eq $bairuiWebPort })
}

function Assert-BairuiListener {
    param([object[]]$Listeners)

    foreach ($bairuiListener in $Listeners) {
        $bairuiOwner = Get-Process -Id $bairuiListener.OwningProcess -ErrorAction SilentlyContinue
        if ($null -eq $bairuiOwner -or [string]::IsNullOrWhiteSpace($bairuiOwner.Path) -or $bairuiOwner.Path -ne $bairuiExecutable) {
            throw "Port $bairuiWebPort is occupied by another process (PID $($bairuiListener.OwningProcess)). No process was stopped."
        }
        if ($bairuiListener.LocalAddress -ne '127.0.0.1') {
            throw "This executable already uses port $bairuiWebPort on a different address. No process was stopped."
        }
    }
}

function Test-BairuiPaths {
    # A listener can appear before the HTTP API is ready. Only a complete,
    # matching response proves that this process uses the portable profile.
    $bairuiHeaders = @{}
    if (-not [string]::IsNullOrEmpty($env:OPENCODE_SERVER_PASSWORD)) {
        $bairuiUsername = $env:OPENCODE_SERVER_USERNAME
        if ($null -eq $bairuiUsername) { $bairuiUsername = 'opencode' }
        $bairuiCredentials = $bairuiUsername + ':' + $env:OPENCODE_SERVER_PASSWORD
        $bairuiHeaders.Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($bairuiCredentials))
    }
    try {
        $bairuiPaths = Invoke-RestMethod -Uri ($bairuiUrl + '/path') -Headers $bairuiHeaders `
            -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
    }
    catch {
        return $false
    }
    $bairuiExpectedPaths = @{
        home = $bairuiProfile
        state = (Join-Path $bairuiInstallRoot 'state\opencode')
        config = (Join-Path $bairuiInstallRoot 'config\opencode')
        directory = $bairuiProjectPath
    }
    foreach ($bairuiPathKey in $bairuiExpectedPaths.Keys) {
        $bairuiActualPath = $bairuiPaths.$bairuiPathKey
        if ($bairuiActualPath -isnot [string] -or [string]::IsNullOrWhiteSpace($bairuiActualPath)) {
            return $false
        }
        try {
            $bairuiActualPath = [IO.Path]::GetFullPath($bairuiActualPath).TrimEnd([char[]]'\/')
            $bairuiExpectedPath = [IO.Path]::GetFullPath($bairuiExpectedPaths[$bairuiPathKey]).TrimEnd([char[]]'\/')
        }
        catch {
            return $false
        }
        if (-not [string]::Equals($bairuiActualPath, $bairuiExpectedPath, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Port $bairuiWebPort uses an unexpected $bairuiPathKey path: $bairuiActualPath (expected $bairuiExpectedPath). No process was stopped."
        }
    }
    return $true
}

$bairuiUrl = "http://127.0.0.1:$bairuiWebPort"
$bairuiLockAcquired = $false
$bairuiKeepLock = $false
try {
    $bairuiLockAcquired = [bool](Acquire-BairuiInstanceLock -Mode $Mode -OwnerPid $PID)

    $bairuiListeners = @(Get-BairuiListener)
    if (-not $bairuiLockAcquired) {
        if ($bairuiListeners.Count -eq 0) {
            throw 'The BAIRUI Web lock is active, but its listener is not available yet. Try again shortly.'
        }
        Assert-BairuiListener -Listeners $bairuiListeners
        if (-not (Test-BairuiPaths)) {
            throw 'The running service could not verify its portable paths through /path. No process was stopped.'
        }
        Write-Output "BAIRUI is already running: $bairuiUrl"
        Write-Output 'The running process keeps its existing settings; changes apply on its next launch.'
        if (-not $NoBrowser) { Start-Process -FilePath $bairuiUrl | Out-Null }
        return
    }

    if ($Mode -eq 'TUI') {
        if ($bairuiListeners.Count -gt 0) {
            throw "BAIRUI Web is already listening on $bairuiUrl. Stop it before starting TUI mode."
        }
        Push-Location -LiteralPath $bairuiProjectPath
        try {
            & $bairuiExecutable
            $bairuiExitCode = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }
        if ($bairuiExitCode -ne 0) {
            throw "BAIRUI TUI exited with code $bairuiExitCode."
        }
        return
    }

    if ($bairuiListeners.Count -gt 0) {
        Assert-BairuiListener -Listeners $bairuiListeners
        if (-not (Test-BairuiPaths)) {
            throw "The running service could not verify its portable paths through /path. No process was stopped."
        }
        Update-BairuiInstanceLockOwner -OwnerPid ([int]$bairuiListeners[0].OwningProcess)
        $bairuiKeepLock = $true
        Write-Output "BAIRUI is already running: $bairuiUrl"
        Write-Output 'The running process keeps its existing settings; changes apply on its next launch.'
        if (-not $NoBrowser) { Start-Process -FilePath $bairuiUrl | Out-Null }
        return
    }

    $bairuiLogDirectory = Join-Path $bairuiInstallRoot 'logs\bairui'
    New-Item -ItemType Directory -Path $bairuiLogDirectory -Force | Out-Null
    $bairuiLogStamp = (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + $PID
    $bairuiStdout = Join-Path $bairuiLogDirectory ($bairuiLogStamp + '.stdout.log')
    $bairuiStderr = Join-Path $bairuiLogDirectory ($bairuiLogStamp + '.stderr.log')

    # The native web command opens a browser itself. serve uses the same HTTP server
    # and lets this launcher honor -NoBrowser.
    $bairuiProcess = Start-Process -FilePath $bairuiExecutable `
        -ArgumentList @('serve', '--hostname', '127.0.0.1', '--port', "$bairuiWebPort") `
        -WorkingDirectory $bairuiProjectPath -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $bairuiStdout -RedirectStandardError $bairuiStderr
    Update-BairuiInstanceLockOwner -OwnerPid ([int]$bairuiProcess.Id)
    $bairuiKeepLock = $true

    $bairuiDeadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $bairuiDeadline) {
        $bairuiProcess.Refresh()
        if ($bairuiProcess.HasExited) {
            throw "BAIRUI exited with code $($bairuiProcess.ExitCode). See $bairuiStderr"
        }
        $bairuiListeners = @(Get-BairuiListener)
        if ($bairuiListeners.Count -gt 0) {
            Assert-BairuiListener -Listeners $bairuiListeners
            if (Test-BairuiPaths) {
                Write-Output "BAIRUI is ready: $bairuiUrl (PID $($bairuiListeners[0].OwningProcess))"
                Write-Output "Logs: $bairuiLogDirectory"
                if (-not $NoBrowser) { Start-Process -FilePath $bairuiUrl | Out-Null }
                return
            }
        }
        Start-Sleep -Milliseconds 500
    }
    throw "BAIRUI did not verify its portable paths through /path within 30 seconds. The process was left running; see $bairuiStderr"
}
finally {
    if ($bairuiLockAcquired -and -not $bairuiKeepLock) {
        Remove-BairuiInstanceLock -ExpectedOwnerPids @($PID)
    }
}
