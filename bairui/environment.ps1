# Windows PowerShell 5.1. Dot-source to use the portable environment checks.
function Get-BairuiEnvironmentComponents {
    param([string]$Root)
    $settings = Get-Content -LiteralPath (Join-Path $Root 'bairui\settings.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($settings.release -notmatch '^[0-9][a-zA-Z0-9._-]*$') { throw '发行版本配置不正确，请重新解压完整的 BAIRUI 安装包。' }
    @(
        [pscustomobject]@{ id = 'app'; name = 'BAIRUI 主程序'; directory = "releases/$($settings.release)"; files = @('opencode.exe', 'release.json'); probes = @(@{ file = 'opencode.exe'; args = '--version' }) },
        [pscustomobject]@{ id = 'bun'; name = 'Bun 运行组件'; directory = 'runtime/bun'; files = @('bun.exe'); probes = @(@{ file = 'bun.exe'; args = '--version' }) },
        [pscustomobject]@{ id = 'node'; name = 'Node.js / npm 运行组件'; directory = 'runtime/node'; files = @('node.exe', 'npm.cmd', 'npx.cmd', 'node_modules/npm/bin/npm-cli.js'); probes = @(@{ file = 'node.exe'; args = '--version' }, @{ file = 'node.exe'; args = 'node_modules/npm/bin/npm-cli.js --version' }) },
        [pscustomobject]@{ id = 'git'; name = 'Git / Bash 文件工具'; directory = 'runtime/git'; files = @('cmd/git.exe', 'bin/bash.exe', 'usr/bin/msys-2.0.dll', 'etc/profile'); probes = @(@{ file = 'cmd/git.exe'; args = '--version' }, @{ file = 'bin/bash.exe'; args = '--noprofile --norc --version' }) }
    )
}

function Test-BairuiEnvironmentComponent {
    param([string]$Root, [object]$Component)
    $directory = Join-Path $Root $Component.directory
    foreach ($file in $Component.files) {
        $path = Join-Path $directory $file
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -eq 0) { return $false }
    }
    foreach ($probe in $Component.probes) {
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo.FileName = Join-Path $directory $probe.file
        $process.StartInfo.Arguments = $probe.args
        $process.StartInfo.WorkingDirectory = $directory
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.RedirectStandardError = $true
        try {
            if (-not $process.Start()) { return $false }
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit(10000)) { $process.Kill(); return $false }
            if ($process.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($stdout.GetAwaiter().GetResult())) { return $false }
        }
        catch { return $false }
        finally { $process.Dispose() }
    }
    return $true
}

function Get-BairuiEnvironmentIssues {
    param([string]$Root)
    $pending = @()
    $pendingPath = Join-Path $Root 'runtime\environment-repair.pending.json'
    if (Test-Path -LiteralPath $pendingPath) {
        try {
            $pending = @(Get-Content -LiteralPath $pendingPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop | ForEach-Object { $_ })
            if ($pending.Count -eq 0 -or @($pending | Where-Object { $_ -notin @('app', 'bun', 'node', 'git') }).Count -gt 0) { throw 'Invalid repair marker' }
        }
        catch { $pending = @('app', 'bun', 'node', 'git') }
    }
    foreach ($component in @(Get-BairuiEnvironmentComponents -Root $Root)) {
        if ($component.id -in $pending -or -not (Test-BairuiEnvironmentComponent -Root $Root -Component $component)) { $component }
    }
}

function Repair-BairuiEnvironment {
    param([string]$Root, [string]$ArchivePath)
    $Root = [IO.Path]::GetFullPath($Root)
    $runtime = Join-Path $Root 'runtime'
    New-Item -ItemType Directory -Path $runtime -Force -ErrorAction Stop | Out-Null
    $lock = $null
    $stage = $null
    try {
        try {
            $lock = [IO.File]::Open((Join-Path $runtime 'environment-repair.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        }
        catch { throw '另一个 BAIRUI 窗口正在补齐环境，请等它完成后再打开。' }
        $issues = @(Get-BairuiEnvironmentIssues -Root $Root)
        if ($issues.Count -eq 0) { return }
        $active = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
            $_.Id -ne $PID -and $_.Path -and (
                $_.Path.StartsWith(($runtime + '\'), [StringComparison]::OrdinalIgnoreCase) -or
                $_.Path.StartsWith((Join-Path $Root 'releases\'), [StringComparison]::OrdinalIgnoreCase))
        })
        if ($active.Count -gt 0) { throw 'BAIRUI 或盘内工具仍在运行。请先关闭终端版，并双击「停止BAIRUI」，再重新打开。' }
        $source = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'environment-release.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $settings = Get-Content -LiteralPath (Join-Path $Root 'bairui\settings.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($settings.release -ne $source.release) { throw '当前版本没有匹配的环境恢复包，请下载该版本的完整便携包重新解压。' }
        $downloads = Join-Path $runtime 'downloads'
        New-Item -ItemType Directory -Path $downloads -Force -ErrorAction Stop | Out-Null
        if ([string]::IsNullOrWhiteSpace($ArchivePath)) {
            $candidates = @(
                (Join-Path $downloads $source.file),
                (Join-Path $Root ('releases\downloads\' + $source.file)),
                (Join-Path (Split-Path -Parent $Root) $source.file)
            )
            $ArchivePath = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
            if (-not $ArchivePath) {
                $ArchivePath = Join-Path $downloads $source.file
                $partial = $ArchivePath + '.part'
                Write-Host '正在下载环境恢复包（约 299 MB），网络较慢时请保留此窗口……'
                [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
                try {
                    Invoke-WebRequest -Uri $source.url -OutFile $partial -UseBasicParsing -TimeoutSec 3600 -ErrorAction Stop
                    if ((Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash -ne $source.sha256) { throw '下载文件校验失败' }
                    Move-Item -LiteralPath $partial -Destination $ArchivePath -Force -ErrorAction Stop
                }
                catch { throw "环境包下载未完成，请检查网络后再次双击启动。已有数据保留。详情：$($_.Exception.Message)" }
            }
        }
        Write-Host '正在校验环境恢复包……'
        if ((Get-Item -LiteralPath $ArchivePath).Length -ne $source.bytes -or (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash -ne $source.sha256) {
            throw "恢复包校验失败，未安装任何组件。请移走该文件后重新启动，或重新下载完整包：$ArchivePath"
        }
        $stage = Join-Path $runtime ('temp\environment-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $stage -Force -ErrorAction Stop | Out-Null
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
        try {
            foreach ($component in $issues) {
                Write-Host "正在准备 $($component.name)……"
                $prefix = 'OpenCode/' + $component.directory + '/'
                foreach ($entry in $archive.Entries) {
                    $entryName = $entry.FullName.Replace('\', '/')
                    if (-not $entryName.StartsWith($prefix, [StringComparison]::Ordinal)) { continue }
                    if ($entryName.EndsWith('/')) { continue }
                    $relative = $entryName.Substring('OpenCode/'.Length)
                    $target = [IO.Path]::GetFullPath((Join-Path $stage $relative))
                    $allowed = [IO.Path]::GetFullPath((Join-Path $stage $component.directory)).TrimEnd('\') + '\'
                    if (-not $target.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw '环境包包含无效文件路径。' }
                    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force -ErrorAction Stop | Out-Null
                    [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $false)
                }
                if (-not (Test-BairuiEnvironmentComponent -Root $stage -Component $component)) { throw "恢复包中的 $($component.name) 无法运行，现有环境没有被替换。" }
            }
        }
        finally { $archive.Dispose() }
        # A durable marker makes interrupted copies retry on the next launch.
        # Restore distribution files only; leave extra files and user data intact.
        $pendingPath = Join-Path $runtime 'environment-repair.pending.json'
        $pendingTemp = $pendingPath + '.tmp'
        ConvertTo-Json -InputObject @($issues | ForEach-Object { $_.id }) | Set-Content -LiteralPath $pendingTemp -Encoding UTF8
        Move-Item -LiteralPath $pendingTemp -Destination $pendingPath -Force -ErrorAction Stop
        foreach ($component in $issues) {
            Write-Host "正在补齐 $($component.name)……"
            $componentRoot = Join-Path $Root $component.directory
            if ((Test-Path -LiteralPath $componentRoot) -and -not (Test-Path -LiteralPath $componentRoot -PathType Container)) {
                throw "组件目录被同名文件占用，请先移走该文件：$componentRoot"
            }
            $stagePrefix = $stage.TrimEnd('\') + '\'
            foreach ($file in Get-ChildItem -LiteralPath (Join-Path $stage $component.directory) -Recurse -File) {
                $target = Join-Path $Root $file.FullName.Substring($stagePrefix.Length)
                New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force -ErrorAction Stop | Out-Null
                $readOnly = (Test-Path -LiteralPath $target -PathType Leaf) -and (Get-Item -LiteralPath $target).IsReadOnly
                try {
                    if ($readOnly) { Set-ItemProperty -LiteralPath $target -Name IsReadOnly -Value $false }
                    [IO.File]::Copy($file.FullName, $target, $true)
                }
                finally {
                    if ($readOnly) { Set-ItemProperty -LiteralPath $target -Name IsReadOnly -Value $true }
                }
            }
            if (-not (Test-BairuiEnvironmentComponent -Root $Root -Component $component)) { throw "$($component.name) 补齐后仍不能运行，请保留此窗口的错误信息。" }
        }
        Remove-Item -LiteralPath $pendingPath -Force -ErrorAction Stop
        Write-Host '环境已补齐，正在继续启动 BAIRUI。' -ForegroundColor Green
    }
    finally {
        if ($stage -and (Test-Path -LiteralPath $stage)) {
            $cleanupPath = [IO.Path]::GetFullPath($stage)
            $tempPrefix = [IO.Path]::GetFullPath((Join-Path $runtime 'temp')).TrimEnd('\') + '\'
            if ($cleanupPath.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($cleanupPath) -match '^environment-[a-f0-9]{32}$') {
                Remove-Item -LiteralPath $cleanupPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        if ($lock) { $lock.Dispose() }
    }
}

function Assert-BairuiEnvironment {
    param([string]$Root, [switch]$Interactive)
    if (-not [Environment]::Is64BitOperatingSystem -or $env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') {
        throw '这个便携包适用于 Windows x64 电脑，请使用匹配电脑架构的发行版。'
    }
    Write-Host '正在检查 BAIRUI 运行环境……'
    $issues = @(Get-BairuiEnvironmentIssues -Root $Root)
    if ($issues.Count -eq 0) { return }
    $names = ($issues | ForEach-Object { '• ' + $_.name }) -join "`r`n"
    $message = "需要补齐以下运行组件：`r`n$names`r`n`r`n点「是」自动补齐并继续启动；点「否」退出。`r`n优先使用本地安装包，没有时联网下载约 299 MB。`r`n组件保存在安装目录内，不需要管理员权限。`r`n聊天记录、模型配置和项目文件保留。"
    if (-not $Interactive) { throw "需要补齐运行环境：`r`n$names`r`n请双击「启动BAIRUI.cmd」，按提示自动补齐。" }
    Add-Type -AssemblyName System.Windows.Forms
    $choice = [System.Windows.Forms.MessageBox]::Show($message, 'BAIRUI · 补齐运行环境', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Information)
    if ($choice -ne [System.Windows.Forms.DialogResult]::Yes) { throw (New-Object OperationCanceledException('已取消启动，未下载或安装环境组件。')) }
    Repair-BairuiEnvironment -Root $Root
}
