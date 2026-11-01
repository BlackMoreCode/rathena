[CmdletBinding()]
param(
    [string]$ServerRoot,
    [string]$OutputPath
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ServerRoot)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrWhiteSpace($scriptPath)) { throw 'Specify -ServerRoot.' }
    $ServerRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)
}
$ServerRoot = (Resolve-Path -LiteralPath $ServerRoot).Path
$referencePath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'cope-gameplay-reference.json'
$reference = [IO.File]::ReadAllText($referencePath) | ConvertFrom-Json
$script:allowed = @{}
foreach ($entry in $reference.Settings) { $script:allowed[[string]$entry.Key] = $true }
$script:activeFiles = @{}
$script:missingFiles = @{}

function Read-GameplayConfig([string]$RelativePath, [hashtable]$Values, [string[]]$Stack = @()) {
    $path = [IO.Path]::GetFullPath((Join-Path $ServerRoot $RelativePath))
    $prefix = $ServerRoot.TrimEnd('\') + '\'
    if (-not $path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Config import leaves ServerRoot.' }
    if ($Stack -contains $path) { throw 'Config import cycle detected.' }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $script:missingFiles[$RelativePath] = $true; return }
    $script:activeFiles[$RelativePath] = $true
    $number = 0
    foreach ($raw in [IO.File]::ReadAllLines($path)) {
        $number++
        $line = $raw.Trim()
        if ($line.Length -eq 0 -or $line.StartsWith('//') -or $line.StartsWith('#')) { continue }
        if ($line -notmatch '^([^:]+):\s*(.*)$') { continue }
        $key = $Matches[1].Trim().ToLowerInvariant()
        $value = ($Matches[2] -split '//', 2)[0].Trim()
        if ($key -eq 'import') { Read-GameplayConfig $value $Values ($Stack + @($path)); continue }
        # Never store or export IP, DB credentials, auth passwords, or arbitrary keys.
        if ($script:allowed.ContainsKey($key)) {
            $Values[$key] = [pscustomobject]@{ Value = $value; Source = $RelativePath; Line = $number }
        }
    }
}

function Normalize-GameplayValue([string]$Value) {
    switch ($Value.ToLowerInvariant()) {
        { $_ -in @('yes','on','true') } { return '1' }
        { $_ -in @('no','off','false') } { return '0' }
        default { return $Value.ToLowerInvariant() }
    }
}

$roots = @{ battle = 'conf/battle_athena.conf'; char = 'conf/char_athena.conf'; login = 'conf/login_athena.conf'; inter = 'conf/inter_athena.conf' }
$valuesByScope = @{}
foreach ($scope in $roots.Keys) {
    $values = @{}
    Read-GameplayConfig $roots[$scope] $values
    $valuesByScope[$scope] = $values
}
$rows = foreach ($entry in $reference.Settings) {
    $actual = $valuesByScope[[string]$entry.Scope][[string]$entry.Key]
    $status = if ($null -eq $actual) { 'NotFound' } elseif ((Normalize-GameplayValue $actual.Value) -eq (Normalize-GameplayValue ([string]$entry.Local))) { 'Match' } else { 'Different' }
    [pscustomobject][ordered]@{
        Scope = $entry.Scope; Key = $entry.Key; ExpectedLocal = $entry.Local
        Actual = $(if ($null -ne $actual) { $actual.Value } else { $null })
        Status = $status; Recommendation = $entry.Recommendation
        Source = $(if ($null -ne $actual) { $actual.Source } else { $null })
    }
}

$groupsPath = Join-Path $ServerRoot 'conf/import/groups.yml'
$groupsExist = Test-Path -LiteralPath $groupsPath -PathType Leaf
$groupBody = if ($groupsExist) {
    $groupText = [IO.File]::ReadAllText($groupsPath)
    # Report the non-secret YAML body as evidence. Do not pretend to implement all YAML inheritance.
    $bodyMatch = [regex]::Match($groupText, '(?ms)^Body:\s*\r?\n(.*?)(?=^Footer:|\z)')
    if ($bodyMatch.Success) { $bodyMatch.Groups[1].Value.Trim() } else { '' }
} else { '' }
$groupHash = ''
if ($groupsExist) {
    $groupStream = [IO.File]::OpenRead($groupsPath)
    $groupHasher = [Security.Cryptography.SHA256]::Create()
    try { $groupHash = [BitConverter]::ToString($groupHasher.ComputeHash($groupStream)).Replace('-', '').ToLowerInvariant() }
    finally { $groupHasher.Dispose(); $groupStream.Dispose() }
}
$report = [ordered]@{
    Reference = $reference.Name
    ConfigFilesModified = $false
    CredentialsOrNetworkValuesIncluded = $false
    Settings = @($rows)
    GroupsImport = [ordered]@{
        Exists = [bool]$groupsExist; SHA256 = $groupHash
        ExactlyMatchesLocalImport = ($groupHash -eq $reference.GroupsImportSHA256)
        Body = $groupBody
        Note = 'Body evidence only; group inheritance and aliases require comparison before editing.'
    }
    ExpectedLocalPlayerCommands = @($reference.PlayerCommands)
    MissingConfigPaths = @($script:missingFiles.Keys | Sort-Object)
    ActiveConfigPaths = @($script:activeFiles.Keys | Sort-Object)
}
$json = $report | ConvertTo-Json -Depth 10
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputFull = [IO.Path]::GetFullPath($OutputPath)
    if ($outputFull.StartsWith($ServerRoot.TrimEnd('\') + '\conf\', [StringComparison]::OrdinalIgnoreCase)) { throw 'OutputPath must not overwrite configuration files.' }
    [IO.File]::WriteAllText($outputFull, $json + "`n", (New-Object Text.UTF8Encoding($false)))
    Write-Output ('Saved non-secret gameplay audit: ' + $outputFull)
    Write-Output ('Differences: ' + @($rows | Where-Object Status -ne 'Match').Count)
    Write-Output ('Groups import matches local: ' + $report.GroupsImport.ExactlyMatchesLocalImport)
    Write-Output 'No configuration, IP, DB credentials, or running processes were changed.'
} else { Write-Output $json }
