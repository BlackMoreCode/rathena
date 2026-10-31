[CmdletBinding()]
param([string]$ServerRoot)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ServerRoot)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrWhiteSpace($scriptPath)) { throw 'Specify -ServerRoot explicitly.' }
    $ServerRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)
}
$ServerRoot = (Resolve-Path -LiteralPath $ServerRoot).Path
$templateRoot = Join-Path $ServerRoot 'conf/msg_conf/import-tmpl'
if (-not (Test-Path -LiteralPath $templateRoot -PathType Container)) {
    throw 'Message template folder not found. Check the rAthena checkout path.'
}
$importRoot = Join-Path $ServerRoot 'conf/msg_conf/import'
New-Item -ItemType Directory -Path $importRoot -Force | Out-Null
$created = 0
$preserved = 0
foreach ($template in Get-ChildItem -LiteralPath $templateRoot -File) {
    $destination = Join-Path $importRoot $template.Name
    if (Test-Path -LiteralPath $destination) { $preserved++; continue }
    Copy-Item -LiteralPath $template.FullName -Destination $destination
    $created++
}
Write-Output "Message imports ready: created $created, preserved $preserved existing files."
