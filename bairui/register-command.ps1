[CmdletBinding()]
param(
    [ValidateSet('User', 'Process')]
    [string]$Scope = 'User',
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'
$bairuiCommandDirectory = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
if (-not (Test-Path -LiteralPath (Join-Path $bairuiCommandDirectory 'bairui.cmd') -PathType Leaf)) {
    throw 'bairui.cmd is missing beside this registration script.'
}

function Update-BairuiPath {
    param([string]$Value)
    $bairuiEntries = @($Value -split ';' | Where-Object { $_ -ne '' })
    $bairuiWithoutCommand = @($bairuiEntries | Where-Object {
        $_.Trim().TrimEnd('\') -ine $bairuiCommandDirectory
    })
    if ($Remove) { return ($bairuiWithoutCommand -join ';') }
    if ($bairuiWithoutCommand.Count -ne $bairuiEntries.Count) { return $Value }
    return (($bairuiEntries + $bairuiCommandDirectory) -join ';')
}

$bairuiOldPath = [Environment]::GetEnvironmentVariable('Path', $Scope)
$bairuiNewPath = Update-BairuiPath -Value $bairuiOldPath
if ($bairuiOldPath -cne $bairuiNewPath) {
    [Environment]::SetEnvironmentVariable('Path', $bairuiNewPath, $Scope)
}
if ($Scope -eq 'User') {
    $env:Path = Update-BairuiPath -Value $env:Path
}
if ($Remove) {
    Write-Output "Removed BAIRUI command registration ($Scope): $bairuiCommandDirectory"
} else {
    Write-Output "BAIRUI command registered ($Scope): $bairuiCommandDirectory"
    Write-Output 'Type bairui to open the TUI. Reopen existing PowerShell/Windows Terminal windows to refresh their PATH.'
}
