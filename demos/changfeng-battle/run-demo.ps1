[CmdletBinding()]
param(
    [string]$GodotPath,
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'

# Also dot-sourced by verification; executable paths never pass through a shell.
function Resolve-DemoGodotPath {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [string]$GodotPath,
        [switch]$PreferConsole
    )
    $candidate = $null
    if (-not [string]::IsNullOrWhiteSpace($GodotPath)) {
        $candidate = $GodotPath
        $source = '-GodotPath'
    } elseif (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) {
        $candidate = $env:GODOT_BIN
        $source = 'GODOT_BIN'
    } else {
        foreach ($name in @('godot', 'godot4')) {
            $command = Get-Command -Name $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($command) { $candidate = $command.Source; break }
        }
        if (-not $candidate) {
            $fallback = Join-Path $ProjectRoot '../../../godot-workspace/godot/bin'
            $names = if ($PreferConsole) {
                @('godot.windows.editor.x86_64.console.exe', 'godot.windows.editor.x86_64.exe')
            } else {
                @('godot.windows.editor.x86_64.exe', 'godot.windows.editor.x86_64.console.exe')
            }
            foreach ($name in $names) {
                $path = Join-Path $fallback $name
                if (Test-Path -LiteralPath $path -PathType Leaf) { $candidate = $path; break }
            }
        }
        $source = 'PATH / 本机 Creator 目录'
    }
    if (-not $candidate -or -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "找不到 Godot 可执行文件（来源：$source）。请用 -GodotPath 指定文件，设置 GODOT_BIN，或将 godot / godot4 加入 PATH。"
    }
    $resolvedPath = (Get-Item -LiteralPath $candidate).FullName
    if (-not $PreferConsole -and $resolvedPath.EndsWith('.console.exe', [StringComparison]::OrdinalIgnoreCase)) {
        $guiPath = $resolvedPath.Substring(0, $resolvedPath.Length - '.console.exe'.Length) + '.exe'
        if (Test-Path -LiteralPath $guiPath -PathType Leaf) { $resolvedPath = $guiPath }
    }
    return $resolvedPath
}

function Test-DemoAssetImportRequired {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)
    $importedRoot = Join-Path $ProjectRoot '.godot/imported'
    if (-not (Test-Path -LiteralPath $importedRoot -PathType Container)) { return $true }

    $assetRoot = Join-Path $ProjectRoot 'assets'
    if (-not (Test-Path -LiteralPath $assetRoot -PathType Container)) { return $false }
    $importedExtensions = @('.png', '.jpg', '.jpeg', '.webp', '.svg', '.bmp', '.tga', '.wav', '.ogg', '.mp3', '.opus')
    foreach ($asset in Get-ChildItem -LiteralPath $assetRoot -Recurse -File) {
        if ($importedExtensions -contains $asset.Extension.ToLowerInvariant() -and
            -not (Test-Path -LiteralPath ($asset.FullName + '.import') -PathType Leaf)) {
            return $true
        }
    }
    return $false
}

function Import-DemoAssets {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$GodotPath,
        [Parameter(Mandatory = $true)][string]$LogPath
    )
    if (Test-Path -LiteralPath $LogPath) { Remove-Item -LiteralPath $LogPath }
    $arguments = @(
        '--headless', '--editor', '--path', ('"{0}"' -f $ProjectRoot),
        '--log-file', ('"{0}"' -f $LogPath), '--import', '--quit'
    )
    $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WorkingDirectory $ProjectRoot -WindowStyle Hidden -PassThru -Wait
    $logText = if (Test-Path -LiteralPath $LogPath) { Get-Content -LiteralPath $LogPath -Raw } else { '' }
    if ($process.ExitCode -ne 0 -or $logText -match '(?im)(SCRIPT ERROR:|Parse Error:|^ERROR:)') {
        if ($logText) { Write-Output $logText.TrimEnd() }
        throw "Godot asset import failed (exit code $($process.ExitCode)). Log: $LogPath"
    }
}

if ($MyInvocation.InvocationName -eq '.') { return }
try {
    $projectRoot = [IO.Path]::GetFullPath($PSScriptRoot)
    $resolvedGodot = Resolve-DemoGodotPath -ProjectRoot $projectRoot -GodotPath $GodotPath
    if ($CheckOnly) { Write-Output "Godot: $resolvedGodot"; exit 0 }
    $captureRoot = Join-Path $projectRoot 'captures'
    [IO.Directory]::CreateDirectory($captureRoot) | Out-Null
    $logPath = Join-Path $captureRoot 'play.log'
    if (Test-DemoAssetImportRequired -ProjectRoot $projectRoot) {
        $importLogPath = Join-Path $captureRoot 'import.log'
        Import-DemoAssets -ProjectRoot $projectRoot -GodotPath $resolvedGodot -LogPath $importLogPath
    }
    # Native argument quoting preserves spaces and shell metacharacters; no shell is invoked.
    $nativeArguments = @('--path', ('"{0}"' -f $projectRoot), '--log-file', ('"{0}"' -f $logPath))
    Start-Process -FilePath $resolvedGodot -ArgumentList $nativeArguments -WorkingDirectory $projectRoot | Out-Null
    Write-Output "已启动长风对战 Demo。日志：$logPath"
} catch {
    [Console]::Error.WriteLine("启动失败：{0}", $_.Exception.Message)
    exit 1
}
