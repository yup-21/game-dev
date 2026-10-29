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

if ($MyInvocation.InvocationName -eq '.') { return }
try {
    $projectRoot = [IO.Path]::GetFullPath($PSScriptRoot)
    $resolvedGodot = Resolve-DemoGodotPath -ProjectRoot $projectRoot -GodotPath $GodotPath
    if ($CheckOnly) { Write-Output "Godot: $resolvedGodot"; exit 0 }
    $captureRoot = Join-Path $projectRoot 'captures'
    [IO.Directory]::CreateDirectory($captureRoot) | Out-Null
    $logPath = Join-Path $captureRoot 'play.log'
    # A fresh checkout has source PNGs but no Godot import cache yet.
    # Import before starting the game so preloaded textures resolve on the first run.
    $importLog = Join-Path $captureRoot 'import.log'
    $importArguments = @('--headless', '--editor', '--path', ('"{0}"' -f $projectRoot), '--quit', '--log-file', ('"{0}"' -f $importLog))
    $importProcess = Start-Process -FilePath $resolvedGodot -ArgumentList $importArguments -WorkingDirectory $projectRoot -PassThru -RedirectStandardOutput (Join-Path $captureRoot 'import.stdout.log') -RedirectStandardError (Join-Path $captureRoot 'import.stderr.log')
    $nativeHandle = $importProcess.Handle
    if (-not $importProcess.WaitForExit(60000)) {
        $importProcess.Kill()
        throw "资源导入超时。日志：$importLog"
    }
    $importProcess.WaitForExit()
    $importText = (@($importLog, (Join-Path $captureRoot 'import.stdout.log'), (Join-Path $captureRoot 'import.stderr.log')) | ForEach-Object { if (Test-Path -LiteralPath $_) { [IO.File]::ReadAllText($_) } }) -join "`n"
    if ($importProcess.ExitCode -ne 0 -or $importText -match '(?m)^(SCRIPT ERROR:|ERROR:)') {
        throw "资源导入失败。日志：$importLog"
    }
    # Native argument quoting preserves spaces and shell metacharacters; no shell is invoked.
    $nativeArguments = @('--path', ('"{0}"' -f $projectRoot), '--log-file', ('"{0}"' -f $logPath))
    Start-Process -FilePath $resolvedGodot -ArgumentList $nativeArguments -WorkingDirectory $projectRoot | Out-Null
    Write-Output "已启动长风对战 Demo。日志：$logPath"
} catch {
    [Console]::Error.WriteLine("启动失败：{0}", $_.Exception.Message)
    exit 1
}
