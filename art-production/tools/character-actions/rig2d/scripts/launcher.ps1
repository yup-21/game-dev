param(
    [string]$Project,
    [string]$Action,
    [string]$Blender,
    [string]$Python,
    [string]$Output,
    [string]$PartsOverride,
    [string]$MotionOverride,
    [ValidateRange(1,4)][int]$Jobs = 2,
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$workflowRoot = Split-Path -Parent $PSScriptRoot
if (-not $Python) {
    $repoRoot = [IO.Path]::GetFullPath((Join-Path $workflowRoot '..\..\..\..'))
    $tools = Join-Path (Split-Path $repoRoot -Parent) 'tools'
    $portable = Join-Path $tools 'comfyui\ComfyUI_windows_portable\python_embeded\python.exe'
    if (Test-Path -LiteralPath $portable) {
        $Python = $portable
    } else {
        $Python = (Get-Command python.exe -ErrorAction Stop).Source
    }
}
$arguments = @('-X', 'utf8', '-s', (Join-Path $PSScriptRoot 'run_workflow.py'), '--jobs', "$Jobs")
if ($Project) { $arguments += @('--project', $Project) }
if ($Blender) { $arguments += @('--blender', $Blender) }
if ($Output) { $arguments += @('--output', $Output) }
if ($PartsOverride) { $arguments += @('--parts-override', $PartsOverride) }
if ($MotionOverride) { $arguments += @('--motion-override', $MotionOverride) }
if ($CheckOnly) { $arguments += '--check-only' }
if ($Action) {
    foreach ($id in $Action.Split(',')) {
        if ($id.Trim()) { $arguments += @('--action', $id.Trim()) }
    }
}
& $Python @arguments
exit $LASTEXITCODE
