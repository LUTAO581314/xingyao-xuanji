[CmdletBinding()]
param([string]$Root)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent $PSScriptRoot }
$bairuiInstallRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Root)
. (Join-Path $PSScriptRoot 'env.ps1') -Root $bairuiInstallRoot

$bairuiSettings = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'settings.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$bairuiName = '星杳'
if ($null -ne $bairuiSettings.assistantName) {
    if ($bairuiSettings.assistantName -isnot [string]) { throw 'settings.json assistantName must be a string.' }
    if (-not [string]::IsNullOrWhiteSpace($bairuiSettings.assistantName)) { $bairuiName = $bairuiSettings.assistantName.Trim() }
}
if (@('build', 'plan', 'general', 'explore', 'compaction', 'title', 'summary') -contains $bairuiName) {
    throw 'assistantName conflicts with a native agent. Choose a distinct assistant name.'
}
$bairuiPromptEnabled = $true
if ($null -ne $bairuiSettings.promptEnabled) {
    if ($bairuiSettings.promptEnabled -isnot [bool]) { throw 'settings.json promptEnabled must be true or false.' }
    $bairuiPromptEnabled = $bairuiSettings.promptEnabled
}
$bairuiRelease = '1.18.31-bairui-brand.2'
if ($null -ne $bairuiSettings.release) {
    if ($bairuiSettings.release -isnot [string] -or $bairuiSettings.release -notmatch '^[0-9][a-zA-Z0-9._-]*$') {
        throw 'settings.json release must name a release directory, without path separators.'
    }
    $bairuiRelease = $bairuiSettings.release
}
$env:BAIRUI_NAME = $bairuiName
$env:BAIRUI_PROMPT_DISABLED = (-not $bairuiPromptEnabled).ToString().ToLowerInvariant()
# Use the native agent/config mechanism. Omitting prompt and model preserves
# provider-specific templates, native model selection, and permission defaults.
$bairuiPrimaryAgents = @{}
$bairuiPrimaryAgents[$bairuiName] = @{
    mode = 'primary'
    description = 'BAIRUI personal assistant'
    color = 'primary'
}
$env:OPENCODE_CONFIG_CONTENT = @{
    default_agent = $bairuiName
    agent = $bairuiPrimaryAgents
} | ConvertTo-Json -Depth 6 -Compress
$bairuiExecutable = Join-Path $bairuiInstallRoot ('releases\' + $bairuiRelease + '\opencode.exe')
if (-not (Test-Path -LiteralPath $bairuiExecutable -PathType Leaf)) {
    throw "BAIRUI release is missing: $bairuiExecutable"
}
$bairuiWebPort = 13148
$bairuiLockPath = Join-Path $bairuiInstallRoot 'runtime\bairui-instance.lock.json'
# Nested commands must re-enter this portable release instead of resolving a
# host-installed OpenCode binary from PATH.
$env:BAIRUI_BIN_PATH = $bairuiExecutable
