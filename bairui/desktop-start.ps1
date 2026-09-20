[CmdletBinding()]
param(
    [string]$Root,
    [ValidateSet('Web', 'TUI')][string]$Mode = 'Web'
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent $PSScriptRoot }
try {
    & (Join-Path $PSScriptRoot 'start.ps1') -Root $Root -Mode $Mode -Interactive
    exit 0
}
catch [OperationCanceledException] {
    Write-Host $_.Exception.Message
    exit 0
}
catch {
    $message = "BAIRUI 暂时无法打开。`r`n`r`n$($_.Exception.Message)`r`n`r`n请保留此窗口的错误信息。若刚下载，请先解压整个安装包，不要在压缩包里直接运行。"
    Write-Host $message -ForegroundColor Red
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show($message, 'BAIRUI · 启动提示', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
    catch { }
    exit 1
}
