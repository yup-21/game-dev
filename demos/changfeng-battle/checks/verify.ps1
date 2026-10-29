[CmdletBinding()]
param(
    [ValidateSet('All','Policy','Rules','Edges','Playthrough','Catalog','Schools','SchoolPlaythrough','Framework','Generated','Lifecycle','Opening','Parties','DemoFlow')][string]$Stage = 'All',
    [string]$GodotPath
)
$ErrorActionPreference = 'Stop'
# The old five-phase checks are archived with their matching source version.
& (Join-Path $PSScriptRoot 'verify-tingfeng.ps1') -Stage $Stage -GodotPath $GodotPath
