[CmdletBinding()]
param(
    [string]$Root
)

# Dot-source this file to prepare the current process and its future children.
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent $PSScriptRoot }
$bairuiRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Root)
if (-not (Test-Path -LiteralPath $bairuiRoot -PathType Container)) {
    throw "BAIRUI root directory does not exist: $bairuiRoot"
}
$bairuiRuntime = Join-Path $bairuiRoot 'runtime'
$bairuiProfile = Join-Path $bairuiRuntime 'profile'
$bairuiCache = Join-Path $bairuiRuntime 'cache'

$bairuiDirectoryEnvironment = @{
    XDG_DATA_HOME = (Join-Path $bairuiRoot 'data')
    XDG_CONFIG_HOME = (Join-Path $bairuiRoot 'config')
    XDG_CACHE_HOME = (Join-Path $bairuiRoot 'cache')
    XDG_STATE_HOME = (Join-Path $bairuiRoot 'state')
    XDG_RUNTIME_DIR = (Join-Path $bairuiRuntime 'session')
    TEMP = (Join-Path $bairuiRuntime 'temp')
    TMP = (Join-Path $bairuiRuntime 'temp')
    TMPDIR = (Join-Path $bairuiRuntime 'temp')
    APPDATA = (Join-Path $bairuiProfile 'AppData\Roaming')
    LOCALAPPDATA = (Join-Path $bairuiProfile 'AppData\Local')
    OPENCODE_TEST_HOME = $bairuiProfile
    OPENCODE_CONFIG_DIR = (Join-Path $bairuiRoot 'config\opencode')
    BUN_INSTALL = (Join-Path $bairuiRuntime 'bun')
    BUN_INSTALL_CACHE_DIR = (Join-Path $bairuiCache 'bun')
    BUN_RUNTIME_TRANSPILER_CACHE_PATH = (Join-Path $bairuiCache 'bun-transpiler')
    NODE_COMPILE_CACHE = (Join-Path $bairuiCache 'node-compile')
    npm_config_cache = (Join-Path $bairuiCache 'npm')
    npm_config_prefix = (Join-Path $bairuiRuntime 'npm')
    npm_config_devdir = (Join-Path $bairuiCache 'node-gyp')
    PIP_CACHE_DIR = (Join-Path $bairuiCache 'pip')
    PYTHONPYCACHEPREFIX = (Join-Path $bairuiCache 'python')
    PYTHONUSERBASE = (Join-Path $bairuiRuntime 'python-user')
    UV_CACHE_DIR = (Join-Path $bairuiCache 'uv')
    NUGET_PACKAGES = (Join-Path $bairuiCache 'nuget')
    CARGO_HOME = (Join-Path $bairuiRuntime 'cargo')
    RUSTUP_HOME = (Join-Path $bairuiRuntime 'rustup')
    PLAYWRIGHT_BROWSERS_PATH = (Join-Path $bairuiCache 'playwright')
    ELECTRON_CACHE = (Join-Path $bairuiCache 'electron')
    GH_CONFIG_DIR = (Join-Path $bairuiProfile 'gh')
}

foreach ($bairuiEntry in $bairuiDirectoryEnvironment.GetEnumerator()) {
    New-Item -ItemType Directory -Path $bairuiEntry.Value -Force -ErrorAction Stop | Out-Null
    [Environment]::SetEnvironmentVariable($bairuiEntry.Key, $bairuiEntry.Value, 'Process')
}

$bairuiFileEnvironment = @{
    GIT_CONFIG_GLOBAL = (Join-Path $bairuiProfile 'gitconfig')
    npm_config_userconfig = (Join-Path $bairuiProfile 'npmrc')
    npm_config_globalconfig = (Join-Path $bairuiProfile 'npm-globalrc')
}
foreach ($bairuiEntry in $bairuiFileEnvironment.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $bairuiEntry.Value)) {
        New-Item -ItemType File -Path $bairuiEntry.Value -ErrorAction Stop | Out-Null
    }
    [Environment]::SetEnvironmentVariable($bairuiEntry.Key, $bairuiEntry.Value, 'Process')
}

$env:NODE_REPL_HISTORY = Join-Path $bairuiProfile 'node_repl_history'
$env:GIT_CONFIG_NOSYSTEM = '1'
$env:OPENCODE_GIT_BASH_PATH = Join-Path $bairuiRuntime 'git\bin\bash.exe'
$env:OPENCODE_DISABLE_CLAUDE_CODE = 'true'
$env:OPENCODE_DISABLE_EXTERNAL_SKILLS = 'true'
$env:OPENCODE_DISABLE_AUTOUPDATE = 'true'
$env:OPENCODE_DISABLE_CHANNEL_DB = 'false'

# Do not inherit host-specific OpenCode file locations or inline configuration.
foreach ($bairuiKey in @('OPENCODE_CONFIG', 'OPENCODE_CONFIG_CONTENT', 'OPENCODE_DB', 'OPENCODE_MODELS_PATH', 'OPENCODE_TUI_CONFIG', 'OPENCODE_PLUGIN_META_FILE')) {
    [Environment]::SetEnvironmentVariable($bairuiKey, $null, 'Process')
}

$bairuiToolPaths = @(
    (Join-Path $bairuiRoot 'bairui'),
    (Join-Path $bairuiRuntime 'bun'),
    (Join-Path $bairuiRuntime 'node'),
    (Join-Path $bairuiRuntime 'git\cmd'),
    (Join-Path $bairuiRuntime 'git\bin'),
    (Join-Path $bairuiRuntime 'npm')
)
# Keep Windows itself available, without silently falling back to host-installed
# npm, Python, Git, or other development environments.
$bairuiSystemPaths = @(
    (Join-Path $env:SystemRoot 'System32'),
    $env:SystemRoot,
    (Join-Path $env:SystemRoot 'System32\Wbem'),
    (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0')
)
$env:Path = ($bairuiToolPaths + $bairuiSystemPaths) -join ';'
