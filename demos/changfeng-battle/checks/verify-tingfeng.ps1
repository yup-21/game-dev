[CmdletBinding()]
param(
    [ValidateSet('All','Policy','Rules','Edges','Playthrough','Catalog','Schools','SchoolPlaythrough','Framework','Generated','Lifecycle','Parties','Opening','DemoFlow','DemoTechnique','UnifiedState','InventorySave')][string]$Stage = 'All',
    [string]$GodotPath
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $projectRoot 'run-demo.ps1') -GodotPath $GodotPath
$resolvedGodot = Resolve-DemoGodotPath -ProjectRoot $projectRoot -GodotPath $GodotPath -PreferConsole
$logRoot = Join-Path $projectRoot 'captures/checks'
[IO.Directory]::CreateDirectory($logRoot) | Out-Null
$checks = @()
if ($Stage -in @('All','Framework')) { $checks += @{ Script = 'res://checks/test_ability_framework.gd'; Log = 'ability-framework.log'; Marker = 'FAILURES 0' } }
if ($Stage -in @('All','Generated')) { $checks += @{ Script = 'res://checks/test_generated_cards.gd'; Log = 'generated-cards.log'; Marker = 'RESULTS 0 failures' } }
if ($Stage -in @('All','Lifecycle')) { $checks += @{ Script = 'res://checks/test_model_lifecycle.gd'; Log = 'model-lifecycle.log'; Marker = 'MODEL LIFECYCLE: \d+ PASS / 0 FAIL' } }
if ($Stage -in @('All','Parties')) { $checks += @{ Script = 'res://checks/test_parties.gd'; Log = 'party-rules.log'; Marker = 'PARTY RULES: 0 failure\(s\)' } }
if ($Stage -in @('All','Opening')) { $checks += @{ Script = 'res://checks/test_opening_story.gd'; Log = 'opening-story.log'; Marker = 'OPENING STORY FAILURES: 0' } }
if ($Stage -in @('All','DemoFlow')) { $checks += @{ Script = 'res://checks/test_demo_flow.gd'; Log = 'demo-flow.log'; Marker = 'DEMO FLOW FAILURES: 0' } }
if ($Stage -in @('All','DemoTechnique')) { $checks += @{ Script = 'res://checks/test_demo_technique.gd'; Log = 'demo-technique.log'; Marker = 'DEMO TECHNIQUE FAILURES: 0' } }
if ($Stage -in @('All','UnifiedState')) { $checks += @{ Script = 'res://checks/test_unified_state_progression.gd'; Log = 'unified-state-progression.log'; Marker = 'UNIFIED STATE PROGRESSION: 0 failures' } }
if ($Stage -in @('All','InventorySave')) { $checks += @{ Script = 'res://checks/test_save_inventory_martial.gd'; Log = 'save-inventory-martial.log'; Marker = 'SAVE INVENTORY MARTIAL: 0 failures' } }
if ($Stage -in @('All','Policy')) { $checks += @{ Script = 'res://checks/test_tingfeng_ai.gd'; Log = 'tingfeng-policy.log'; Marker = 'RESULTS: \d+ PASS / 0 FAIL - context-only tingfeng policy' } }
if ($Stage -in @('All','Rules')) { $checks += @{ Script = 'res://checks/test_tingfeng.gd'; Log = 'tingfeng-rules.log'; Marker = 'RESULTS: \d+ PASS / 0 FAIL - targeted tingfeng migration' } }
if ($Stage -in @('All','Edges')) { $checks += @{ Script = 'res://checks/test_tingfeng_edges.gd'; Log = 'tingfeng-edges.log'; Marker = 'EDGE AUDIT: \d+ PASS / 0 failures' } }
if ($Stage -in @('All','Playthrough')) { $checks += @{ Script = 'res://checks/test_tingfeng_playthrough.gd'; Log = 'tingfeng-playthrough.log'; Marker = 'RESULTS: 0 FAIL - symmetric tingfeng playthroughs and seeded replay' } }
if ($Stage -in @('All','Schools')) { $checks += @{ Script = 'res://checks/test_wuxue_v3.gd'; Log = 'wuxue-v3.log'; Marker = 'SCHOOL TESTS: \d+ PASS / 0 FAIL' } }
if ($Stage -in @('All','Catalog')) { $checks += @{ Script = 'res://checks/test_wuxue_catalog.gd'; Log = 'wuxue-catalog.log'; Marker = 'CATALOG CHECK: \d+ checks, 0 failures' } }
if ($Stage -in @('All','SchoolPlaythrough')) { $checks += @{ Script = 'res://checks/test_wuxue_playthrough.gd'; Log = 'wuxue-playthrough.log'; Marker = 'SCHOOL PLAYTHROUGHS: 0 FAIL' } }
foreach ($check in $checks) {
    $logPath = Join-Path $logRoot $check.Log
    if (Test-Path -LiteralPath $logPath) { Remove-Item -LiteralPath $logPath }
    $processArgs = @('--headless', '--path', ('"' + $projectRoot + '"'), '--log-file', ('"' + $logPath + '"'), '--script', $check.Script)
    $checkClock = [Diagnostics.Stopwatch]::StartNew()
    $process = Start-Process -FilePath $resolvedGodot -ArgumentList $processArgs -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru
    $timeoutMs = if ($check.Script -eq 'res://checks/test_wuxue_playthrough.gd') { 180000 } else { 60000 }
    if (-not $process.WaitForExit($timeoutMs)) {
        $process.Kill()
        $process.WaitForExit()
        if (Test-Path -LiteralPath $logPath) { Write-Output (Get-Content -LiteralPath $logPath -Raw) }
        throw "校验 $($check.Script) 超过 $($timeoutMs / 1000) 秒，已停止。日志：$logPath"
    }
    $checkClock.Stop()
    Add-Content -LiteralPath $logPath -Value ("CHECK TIME: {0} {1} ms" -f $check.Script, $checkClock.ElapsedMilliseconds) -Encoding utf8
    $process.Refresh()
    $logText = if (Test-Path -LiteralPath $logPath) { Get-Content -LiteralPath $logPath -Raw } else { '' }
    if ($logText) { Write-Output $logText.TrimEnd() }
    if ($process.ExitCode -ne 0) { throw "校验 $($check.Script) 失败（退出码 $($process.ExitCode)）。日志：$logPath" }
    if ($logText -match '(?im)(SCRIPT ERROR:|Parse Error:|^ERROR:|^FAIL:|^FAILED:)') { throw "Godot 日志包含错误：$logPath" }
    if ($logText -notmatch $check.Marker) { throw "日志中缺少成功标记：$logPath" }
}
Write-Output 'Targeted tingfeng verification passed.'
