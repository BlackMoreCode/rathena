[CmdletBinding()]
param([string]$ServerRoot)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ServerRoot)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrWhiteSpace($scriptPath)) { throw 'Specify -ServerRoot explicitly.' }
    $ServerRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)
}
$ServerRoot = (Resolve-Path -LiteralPath $ServerRoot).Path
foreach ($name in @('login-server.exe','char-server.exe','web-server.exe','map-server.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $ServerRoot $name))) { throw "Missing $name. Build Release x64 first." }
}
foreach ($name in @('login-server.exe','char-server.exe','web-server.exe','map-server.exe')) {
    $fullPath = Join-Path $ServerRoot $name
    $existing = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -eq $name -and $_.ExecutablePath -eq $fullPath })
    if ($existing.Count) { Write-Output "$name already running; skipped."; continue }
    Start-Process -FilePath 'cmd.exe' -ArgumentList '/k', $name -WorkingDirectory $ServerRoot -WindowStyle Normal
    Write-Output "Started $name in a visible console."
}
