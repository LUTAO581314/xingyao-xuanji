# Keep native CLI arguments unbound, including --help, -m, and subcommands.
$bairuiCliArguments = @($args)
. (Join-Path $PSScriptRoot 'launch-env.ps1')

$bairuiWorkingDirectory = (Get-Location).Path
if ([IO.Path]::GetPathRoot($bairuiWorkingDirectory) -ne [IO.Path]::GetPathRoot($bairuiInstallRoot)) {
    $bairuiWorkingDirectory = [IO.Path]::GetPathRoot($bairuiInstallRoot)
}
Push-Location -LiteralPath $bairuiWorkingDirectory
try {
    if ($bairuiCliArguments.Count -eq 0) {
        & (Join-Path $PSScriptRoot 'start.ps1') -Root $bairuiInstallRoot -Mode TUI -Project $bairuiWorkingDirectory
    }
    else {
        & $bairuiExecutable @bairuiCliArguments
    }
    $bairuiExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}
exit $bairuiExitCode
