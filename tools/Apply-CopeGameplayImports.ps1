[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true)][string]$ServerRoot,
    [Parameter(Mandatory=$true)][string]$PackageRoot
)
$ErrorActionPreference = 'Stop'
$ServerRoot = (Resolve-Path -LiteralPath $ServerRoot).ProviderPath
$PackageRoot = (Resolve-Path -LiteralPath $PackageRoot).ProviderPath
if (-not (Test-Path -LiteralPath (Join-Path $ServerRoot 'conf/char_athena.conf'))) { throw 'Invalid ServerRoot.' }
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$reference = [IO.File]::ReadAllText((Join-Path $PackageRoot 'cope-gameplay-reference.json'), $utf8) | ConvertFrom-Json
$scopes = [ordered]@{ 'battle_conf.txt' = 'battle'; 'char_conf.txt' = 'char'; 'login_conf.txt' = 'login' }
$begin = '// BEGIN COPE GAMEPLAY IMPORT'
$end = '// END COPE GAMEPLAY IMPORT'
$blockPattern = '(?ms)^' + [regex]::Escape($begin) + '\r?\n.*?^' + [regex]::Escape($end) + '(?:\r?\n|\z)'
$plans = @()
foreach ($name in $scopes.Keys) {
    $scope = $scopes[$name]
    $source = Join-Path $PackageRoot ('conf/import/' + $name)
    $target = Join-Path $ServerRoot ('conf/import/' + $name)
    $allowed = @{}
    foreach ($entry in $reference.Settings | Where-Object Scope -eq $scope) { $allowed[[string]$entry.Key] = [string]$entry.Local }
    $settings = [ordered]@{}
    foreach ($raw in [IO.File]::ReadAllLines($source, $utf8)) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('//') -or $line.StartsWith('#')) { continue }
        if ($line -notmatch '^([^:]+):\s*(.*)$') { throw ('Invalid source line in ' + $name) }
        $key = $Matches[1].Trim().ToLowerInvariant()
        $value = ($Matches[2] -split '//', 2)[0].Trim()
        if ($key -eq 'import') {
            if ($scope -notin @('char','login') -or $value -ne ('conf/import/cope-network/' + $scope + '.conf')) { throw 'Unexpected source import.' }
            continue
        }
        if (-not $allowed.ContainsKey($key)) { throw ('Unapproved gameplay key: ' + $key) }
        $settings[$key] = $value
    }
    foreach ($key in $settings.Keys) {
        if ($settings[$key] -ne $allowed[$key]) { throw ('Source differs from reviewed local reference: ' + $key) }
    }
    $existing = if (Test-Path -LiteralPath $target) { [IO.File]::ReadAllText($target, $utf8) } else { '' }
    if ([regex]::Matches($existing, $blockPattern).Count -gt 1) { throw ('Multiple managed blocks in ' + $name) }
    if ($existing.Contains($begin) -and -not [regex]::IsMatch($existing, $blockPattern)) { throw ('Incomplete managed block in ' + $name) }
    $newBlock = $begin + "`r`n" + (($settings.Keys | ForEach-Object { $_ + ': ' + $settings[$_] }) -join "`r`n") + "`r`n" + $end + "`r`n"
    $updated = if ([regex]::IsMatch($existing, $blockPattern)) {
        # MatchEvaluator keeps any literal '$' or backslashes in values unchanged.
        [regex]::Replace($existing, $blockPattern, [Text.RegularExpressions.MatchEvaluator]{ param($match) $newBlock })
    } else {
        $existing + $(if ($existing -and -not $existing.EndsWith("`n")) { "`r`n" } else { '' }) + $newBlock
    }
    if ($scope -in @('char','login')) {
        $networkLine = 'import: conf/import/cope-network/' + $scope + '.conf'
        if (-not (Test-Path -LiteralPath (Join-Path $ServerRoot ('conf/import/cope-network/' + $scope + '.conf')))) { throw ('Missing production network profile for ' + $scope) }
        if (-not [regex]::IsMatch($updated, '(?m)^\s*' + [regex]::Escape($networkLine) + '\s*\r?$')) { $updated += $networkLine + "`r`n" }
    }
    $bom = $false
    if (Test-Path -LiteralPath $target) {
        $bytes = [IO.File]::ReadAllBytes($target)
        $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191
    }
    $plans += [pscustomobject]@{ Name = $name; Target = $target; Text = $updated; Bom = $bom; Keys = $settings.Count; Changed = ($updated -cne $existing) }
}
$groupSource = Join-Path $PackageRoot 'conf/import/groups.yml'
$groupBytes = [IO.File]::ReadAllBytes($groupSource)
$sha = [Security.Cryptography.SHA256]::Create()
try { $groupHash = [BitConverter]::ToString($sha.ComputeHash($groupBytes)).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
if ($groupHash -ne $reference.GroupsImportSHA256) { throw 'Groups source differs from the reviewed local file.' }
$groupTarget = Join-Path $ServerRoot 'conf/import/groups.yml'
$groupsChanged = $true
if (Test-Path -LiteralPath $groupTarget) {
    $currentBytes = [IO.File]::ReadAllBytes($groupTarget)
    $groupsChanged = [Convert]::ToBase64String($currentBytes) -cne [Convert]::ToBase64String($groupBytes)
    $groupText = [IO.File]::ReadAllText($groupTarget, $utf8)
    $currentHasher = [Security.Cryptography.SHA256]::Create()
    try { $currentGroupHash = [BitConverter]::ToString($currentHasher.ComputeHash($currentBytes)).Replace('-', '').ToLowerInvariant() } finally { $currentHasher.Dispose() }
    if ($groupsChanged -and -not [string]::IsNullOrWhiteSpace($groupText) -and $currentGroupHash -ne $reference.GroupsTemplateSHA256) {
        throw 'Production groups.yml differs from both the reviewed local file and the empty import template. No files were changed; compare group settings first.'
    }
}
$changedPlans = @($plans | Where-Object Changed)
if ($changedPlans.Count -eq 0 -and -not $groupsChanged) { Write-Output 'Gameplay imports already match. No files changed.'; return }
if (-not $PSCmdlet.ShouldProcess($ServerRoot, 'Apply reviewed gameplay overrides, preserving existing machine settings')) { return }
# Protect backups even on an older checkout without the new tracked ignore rule.
$gitInfo = Join-Path $ServerRoot '.git/info'
if (Test-Path -LiteralPath (Join-Path $ServerRoot '.git') -PathType Container) {
    New-Item -ItemType Directory -Path $gitInfo -Force | Out-Null
    $excludePath = Join-Path $gitInfo 'exclude'
    $excludeText = if (Test-Path -LiteralPath $excludePath) { [IO.File]::ReadAllText($excludePath, $utf8) } else { '' }
    if (-not [regex]::IsMatch($excludeText, '(?m)^/backup-config/\s*\r?$')) {
        [IO.File]::WriteAllText($excludePath, $excludeText + "`r`n/backup-config/`r`n", (New-Object Text.UTF8Encoding($false)))
    }
}
$backup = Join-Path $ServerRoot ('backup-config/cope-gameplay-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $backup -Force | Out-Null
foreach ($plan in $changedPlans) {
    if (Test-Path -LiteralPath $plan.Target) { [IO.File]::Copy($plan.Target, (Join-Path $backup $plan.Name)) }
}
if ($groupsChanged -and (Test-Path -LiteralPath $groupTarget)) { [IO.File]::Copy($groupTarget, (Join-Path $backup 'groups.yml')) }
$tempFiles = @()
try {
    foreach ($plan in $changedPlans) {
        $parent = Split-Path -Parent $plan.Target
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        $temp = $plan.Target + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
        $tempFiles += $temp
        [IO.File]::WriteAllText($temp, $plan.Text, (New-Object Text.UTF8Encoding([bool]$plan.Bom)))
        if (Test-Path -LiteralPath $plan.Target) { [IO.File]::Replace($temp, $plan.Target, [NullString]::Value) } else { [IO.File]::Move($temp, $plan.Target) }
        Write-Output ('Applied ' + $plan.Name + ': ' + $plan.Keys + ' gameplay keys.')
    }
    if ($groupsChanged) {
        $temp = $groupTarget + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
        $tempFiles += $temp
        [IO.File]::WriteAllBytes($temp, $groupBytes)
        if (Test-Path -LiteralPath $groupTarget) { [IO.File]::Replace($temp, $groupTarget, [NullString]::Value) } else { [IO.File]::Move($temp, $groupTarget) }
        Write-Output 'Applied groups.yml player command permissions.'
    }
} catch { throw ('Apply failed. Original files are backed up at ' + $backup + '. ' + $_.Exception.Message) }
finally { foreach ($temp in $tempFiles) { if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) } } }
Write-Output ('Backup: ' + $backup)
Write-Output 'IP, ports, DB credentials, inter_conf.txt, and cope-network files were preserved. No processes were restarted.'
