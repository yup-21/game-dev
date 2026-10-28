[CmdletBinding()]
param(
    [ValidateSet('All','Policy','Rules','Edges','Playthrough')][string]$Stage = 'All',
    [string]$GodotPath
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $projectRoot 'run-demo.ps1') -GodotPath $GodotPath
$resolvedGodot = Resolve-DemoGodotPath -ProjectRoot $projectRoot -GodotPath $GodotPath -PreferConsole
$logRoot = Join-Path $projectRoot 'captures/checks'
[IO.Directory]::CreateDirectory($logRoot) | Out-Null
$checks = @()
if ($Stage -in @('All','Policy')) { $checks += @{ Script = 'res://checks/test_tingfeng_ai.gd'; Log = 'tingfeng-policy.log'; Marker = 'RESULTS: \d+ PASS / 0 FAIL - context-only tingfeng policy' } }
if ($Stage -in @('All','Rules')) { $checks += @{ Script = 'res://checks/test_tingfeng.gd'; Log = 'tingfeng-rules.log'; Marker = 'RESULTS: \d+ PASS / 0 FAIL - targeted tingfeng migration' } }
if ($Stage -in @('All','Edges')) { $checks += @{ Script = 'res://checks/test_tingfeng_edges.gd'; Log = 'tingfeng-edges.log'; Marker = 'EDGE AUDIT: \d+ PASS / 0 failures' } }
if ($Stage -in @('All','Playthrough')) { $checks += @{ Script = 'res://checks/test_tingfeng_playthrough.gd'; Log = 'tingfeng-playthrough.log'; Marker = 'RESULTS: 0 FAIL - symmetric tingfeng playthroughs and seeded replay' } }
foreach ($check in $checks) {
    $logPath = Join-Path $logRoot $check.Log
    if (Test-Path -LiteralPath $logPath) { Remove-Item -LiteralPath $logPath }
    $processArgs = @('--headless', '--path', ('"' + $projectRoot + '"'), '--log-file', ('"' + $logPath + '"'), '--script', $check.Script)
    $process = Start-Process -FilePath $resolvedGodot -ArgumentList $processArgs -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(60000)) {
        $process.Kill()
        $process.WaitForExit()
        if (Test-Path -LiteralPath $logPath) { Write-Output (Get-Content -LiteralPath $logPath -Raw) }
        throw "校验 $($check.Script) 超过 60 秒，已停止。日志：$logPath"
    }
    $process.Refresh()
    $logText = if (Test-Path -LiteralPath $logPath) { Get-Content -LiteralPath $logPath -Raw } else { '' }
    if ($logText) { Write-Output $logText.TrimEnd() }
    if ($process.ExitCode -ne 0) { throw "校验 $($check.Script) 失败（退出码 $($process.ExitCode)）。日志：$logPath" }
    if ($logText -match '(?im)(SCRIPT ERROR:|Parse Error:|^ERROR:|^FAIL:|^FAILED:)') { throw "Godot 日志包含错误：$logPath" }
    if ($logText -notmatch $check.Marker) { throw "日志中缺少成功标记：$logPath" }
}
Write-Output 'Targeted tingfeng verification passed.'
