param(
    [string]$WorkspacePath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [ValidateSet("Error", "Warning", "Information", "Hint")]
    [string]$CheckLevel = "Warning",
    [ValidateSet("Agent", "Pretty", "Json")]
    [string]$OutputMode = "Agent",
    [switch]$FailOnDiagnostics
)

$extensionsDir = Join-Path $env:USERPROFILE ".vscode\extensions"
if (-not (Test-Path $extensionsDir)) {
    Write-Error "VS Code extensions directory not found: $extensionsDir"
    exit 1
}

$extensionRoots = Get-ChildItem $extensionsDir -Directory |
    Where-Object { $_.Name -like "sumneko.lua-*" -or $_.Name -like "luaide.lua-*" } |
    Sort-Object LastWriteTime -Descending

$serverBin = $null
foreach ($root in $extensionRoots) {
    $candidate = Join-Path $root.FullName "server\bin\lua-language-server.exe"
    if (Test-Path $candidate) {
        $serverBin = $candidate
        break
    }
}

if (-not $serverBin) {
    Write-Error "Could not find lua-language-server.exe in installed VS Code Lua extension folders."
    exit 1
}

$workspaceResolved = (Resolve-Path $WorkspacePath).Path
Write-Host "Using LuaLS: $serverBin"
Write-Host "Checking workspace: $workspaceResolved"
Write-Host "Diagnostic level: $CheckLevel"
Write-Host "Output mode: $OutputMode"

if ($OutputMode -eq "Pretty") {
    & $serverBin "--check=$workspaceResolved" "--check_format=pretty" "--checklevel=$CheckLevel"
    exit $LASTEXITCODE
}

$jsonOut = Join-Path $workspaceResolved ".luals-check.json"
if (Test-Path $jsonOut) {
    Remove-Item $jsonOut -Force
}

& $serverBin "--check=$workspaceResolved" "--check_format=json" "--check_out_path=$jsonOut" "--checklevel=$CheckLevel"
$lualsExit = $LASTEXITCODE

if (-not (Test-Path $jsonOut)) {
    Write-Error "LuaLS did not produce expected output file: $jsonOut"
    exit 1
}

$raw = Get-Content $jsonOut -Raw
$diagnosticsByFileObject = $null
if ($raw -and $raw.Trim()) {
    $diagnosticsByFileObject = ConvertFrom-Json $raw
}

if ($OutputMode -eq "Json") {
    Write-Output $raw
} else {
    $severityMap = @{
        1 = "Error"
        2 = "Warning"
        3 = "Information"
        4 = "Hint"
    }

    $summary = [ordered]@{
        files = 0
        diagnostics = 0
        Error = 0
        Warning = 0
        Information = 0
        Hint = 0
    }

    if ($diagnosticsByFileObject) {
        $fileEntries = $diagnosticsByFileObject.PSObject.Properties
    } else {
        $fileEntries = @()
    }

    foreach ($entry in $fileEntries) {
        $fileUri = [string]$entry.Name
        $fileDiagnostics = @($entry.Value)
        if ($fileDiagnostics.Count -eq 0) {
            continue
        }

        $summary.files += 1

        $uriPath = ($fileUri -replace "^file://", "")
        $decodedPath = [System.Uri]::UnescapeDataString($uriPath)
        foreach ($d in $fileDiagnostics) {
            $line = [int]$d.range.start.line + 1
            $col = [int]$d.range.start.character + 1
            $severity = $severityMap[[int]$d.severity]
            if (-not $severity) {
                $severity = "Unknown"
            }

            $summary.diagnostics += 1
            if ($summary.Contains($severity)) {
                $summary[$severity] += 1
            }

            $code = if ($d.code) { [string]$d.code } else { "n/a" }
            $message = if ($d.message) { ([string]$d.message -replace "[\r\n]+", " ").Trim() } else { "(no message)" }
            Write-Output ("AGENT_DIAGNOSTIC|{0}|{1}:{2}:{3}|{4}|{5}" -f $severity, $decodedPath, $line, $col, $code, $message)
        }
    }

    $summaryJson = $summary | ConvertTo-Json -Compress
    Write-Output ("AGENT_SUMMARY|{0}" -f $summaryJson)

    if ($FailOnDiagnostics -and $summary.diagnostics -gt 0) {
        if (Test-Path $jsonOut) {
            Remove-Item $jsonOut -Force
        }
        exit 2
    }
}

if (Test-Path $jsonOut) {
    Remove-Item $jsonOut -Force
}

exit $lualsExit
