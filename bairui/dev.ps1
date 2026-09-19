[CmdletBinding()]
param(
    [string]$Root,
    [ValidateSet('root', 'core', 'opencode', 'app')]
    [string]$Package = 'root',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Command
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent $PSScriptRoot }
. (Join-Path $PSScriptRoot 'env.ps1') -Root $Root
$env:HUSKY = '0'
$bairuiSource = Join-Path $bairuiRoot 'product'
if ($Package -ne 'root') { $bairuiSource = Join-Path $bairuiSource ('packages\' + $Package) }
if (-not $Command) { throw 'Pass a Bun command, for example: -Package core test test/bairui-prompt.test.ts' }
Push-Location -LiteralPath $bairuiSource
try {
    & (Join-Path $bairuiRuntime 'bun\bun.exe') @Command
    $bairuiExit = $LASTEXITCODE
}
finally {
    Pop-Location
}
exit $bairuiExit
