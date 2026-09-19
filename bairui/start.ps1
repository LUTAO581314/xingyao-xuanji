[CmdletBinding()]
param(
    [string]$Root,
    [ValidateSet('Web', 'TUI')]
    [string]$Mode = 'Web',
    [string]$Project,
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent $PSScriptRoot }
$bairuiInstallRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Root)
. (Join-Path $PSScriptRoot 'env.ps1') -Root $bairuiInstallRoot

$bairuiSettingsPath = Join-Path $PSScriptRoot 'settings.json'
$bairuiSettings = Get-Content -LiteralPath $bairuiSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$bairuiName = '星杳'
if ($null -ne $bairuiSettings.assistantName) {
    if ($bairuiSettings.assistantName -isnot [string]) {
        throw 'settings.json assistantName must be a string.'
    }
    if (-not [string]::IsNullOrWhiteSpace($bairuiSettings.assistantName)) {
        $bairuiName = $bairuiSettings.assistantName.Trim()
    }
}
$bairuiPromptEnabled = $true
if ($null -ne $bairuiSettings.promptEnabled) {
    if ($bairuiSettings.promptEnabled -isnot [bool]) {
        throw 'settings.json promptEnabled must be true or false.'
    }
    $bairuiPromptEnabled = $bairuiSettings.promptEnabled
}
$env:BAIRUI_NAME = $bairuiName
$env:BAIRUI_PROMPT_DISABLED = (-not $bairuiPromptEnabled).ToString().ToLowerInvariant()

$bairuiExecutable = Join-Path $bairuiInstallRoot 'releases\1.18.31-bairui-prompt.1\opencode.exe'
foreach ($bairuiRequiredFile in @(
    $bairuiExecutable,
    (Join-Path $bairuiInstallRoot 'runtime\bun\bun.exe'),
    (Join-Path $bairuiInstallRoot 'runtime\node\node.exe'),
    (Join-Path $bairuiInstallRoot 'runtime\git\cmd\git.exe'),
    (Join-Path $bairuiInstallRoot 'runtime\git\bin\bash.exe')
)) {
    if (-not (Test-Path -LiteralPath $bairuiRequiredFile -PathType Leaf)) {
        throw "Required portable file is missing: $bairuiRequiredFile"
    }
}

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

if ($Mode -eq 'TUI') {
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

function Get-BairuiListener {
    @(Get-NetTCPConnection -ErrorAction Stop | Where-Object { $_.State -eq 'Listen' -and $_.LocalPort -eq 4098 })
}

function Assert-BairuiListener {
    param([object[]]$Listeners)

    foreach ($bairuiListener in $Listeners) {
        $bairuiOwner = Get-Process -Id $bairuiListener.OwningProcess -ErrorAction SilentlyContinue
        if ($null -eq $bairuiOwner -or [string]::IsNullOrWhiteSpace($bairuiOwner.Path) -or $bairuiOwner.Path -ne $bairuiExecutable) {
            throw "Port 4098 is occupied by another process (PID $($bairuiListener.OwningProcess)). No process was stopped."
        }
        if ($bairuiListener.LocalAddress -ne '127.0.0.1') {
            throw 'This executable already uses port 4098 on a different address. No process was stopped.'
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
            throw "Port 4098 uses an unexpected $bairuiPathKey path: $bairuiActualPath (expected $bairuiExpectedPath). No process was stopped."
        }
    }
    return $true
}

$bairuiUrl = 'http://127.0.0.1:4098'
$bairuiListeners = @(Get-BairuiListener)
if ($bairuiListeners.Count -gt 0) {
    Assert-BairuiListener -Listeners $bairuiListeners
    if (-not (Test-BairuiPaths)) {
        throw 'The running service could not verify its portable paths through /path. No process was stopped.'
    }
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
    -ArgumentList @('serve', '--hostname', '127.0.0.1', '--port', '4098') `
    -WorkingDirectory $bairuiProjectPath -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput $bairuiStdout -RedirectStandardError $bairuiStderr

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
