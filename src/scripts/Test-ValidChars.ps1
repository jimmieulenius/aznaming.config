<#
.SYNOPSIS
    Comparison and coverage test for Convert-ConstraintToRegex.
.DESCRIPTION
    Part 1 — Comparison Test:
        Reads all config JSON files from config/*.json.
        For each resource with a validChars value, calls Convert-ConstraintToRegex.
        Compares the generated regex against the existing regex value in the JSON.
        Reports: matches, improvements, regressions, and still-unhandled.

    Part 2 — Coverage Report:
        Runs against all lines in config/validChars.txt.
        Produces a summary: how many lines produce a valid regex,
        how many fall back to default, how many return null.
.NOTES
    Run from the repository root:
        pwsh -File src/scripts/%Test-ValidChars.ps1
#>

#region Setup

$ErrorActionPreference = 'Stop'

# Resolve paths relative to repo root
$repoRoot   = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$configDir  = Join-Path $repoRoot 'config'

# Dot-source the new Convert-ConstraintToRegex function
$functionFile = Join-Path $repoRoot `
    'src/modules/Az.Naming.Config/Source/Functions/Convert-ConstraintToRegex.ps1'
. $functionFile

#endregion Setup

# ═══════════════════════════════════════════════════════════════════════════
#region Part 1 — Comparison Test (config JSON files)
# ═══════════════════════════════════════════════════════════════════════════

Write-Host ''
Write-Host '═══════════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host '  Part 1 — Comparison Test (config/*.json)'                     -ForegroundColor Cyan
Write-Host '═══════════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host ''

$jsonFiles = Get-ChildItem -Path $configDir -Filter '*.json' `
    | Sort-Object Name

# Counters
$totalResources    = 0
$withValidChars    = 0
$matchCount        = 0
$improvementCount  = 0
$regressionCount   = 0
$unhandledCount    = 0

# Detail collections
$matches_      = [System.Collections.Generic.List[string]]::new()
$improvements  = [System.Collections.Generic.List[string]]::new()
$regressions   = [System.Collections.Generic.List[string]]::new()
$unhandled     = [System.Collections.Generic.List[string]]::new()

foreach ($file in $jsonFiles) {
    $json = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json

    # Each top-level property is a resource type
    $json.PSObject.Properties | ForEach-Object {
        $resourceType = $_.Name
        $policy       = $_.Value.policy
        $constraints  = $policy.constraints

        $totalResources++

        if (-not $constraints.validChars) {
            return  # skip resources without validChars
        }

        $withValidChars++

        # Build input hashtable matching the function's expected shape
        $input = [ordered]@{
            validChars = $constraints.validChars
            minLength  = $constraints.minLength
            maxLength  = $constraints.maxLength
        }

        # Call the new function
        $generated = $input | Convert-ConstraintToRegex
        $existing  = $constraints.pattern

        # Classify result
        if ($generated -and $existing -and $generated -eq $existing) {
            # Exact match
            $matchCount++
            $matches_.Add("  [=] $resourceType")
        }
        elseif ($generated -and (-not $existing -or $existing -eq '')) {
            # Improvement: was null/empty, now has a regex
            $improvementCount++
            $improvements.Add(
                "  [+] $resourceType`n" +
                "      validChars: $($constraints.validChars)`n" +
                "      old regex:  (empty)`n" +
                "      new regex:  $generated"
            )
        }
        elseif ($generated -and $existing -and $generated -ne $existing) {
            # Different — could be improvement or regression
            # Heuristic: if old regex looks wrong (missing ^ or $, or very short), treat as improvement
            $isLikelyImprovement = (
                -not $existing.StartsWith('^') -or
                -not $existing.EndsWith('$') -or
                $existing.Length -lt 5
            )

            if ($isLikelyImprovement) {
                $improvementCount++
                $improvements.Add(
                    "  [+] $resourceType`n" +
                    "      validChars: $($constraints.validChars)`n" +
                    "      old regex:  $existing`n" +
                    "      new regex:  $generated"
                )
            }
            else {
                $regressionCount++
                $regressions.Add(
                    "  [!] $resourceType`n" +
                    "      validChars: $($constraints.validChars)`n" +
                    "      old regex:  $existing`n" +
                    "      new regex:  $generated"
                )
            }
        }
        elseif (-not $generated) {
            # Could not generate a regex
            $unhandledCount++
            $unhandled.Add(
                "  [?] $resourceType`n" +
                "      validChars: $($constraints.validChars)`n" +
                "      old regex:  $existing"
            )
        }
    }
}

# ── Summary ──────────────────────────────────────────────────────────────
Write-Host '── Summary ──────────────────────────────────────────────────' -ForegroundColor Yellow
Write-Host "  Total resources:       $totalResources"
Write-Host "  With validChars:       $withValidChars"
Write-Host ''
Write-Host "  Exact matches:         $matchCount"       -ForegroundColor Green
Write-Host "  Improvements:          $improvementCount"  -ForegroundColor Cyan
Write-Host "  Regressions:           $regressionCount"   -ForegroundColor Red
Write-Host "  Still unhandled:       $unhandledCount"    -ForegroundColor DarkYellow
Write-Host ''

if ($matches_.Count -gt 0) {
    Write-Host '── Exact Matches ────────────────────────────────────────────' -ForegroundColor Green
    $matches_ | ForEach-Object { Write-Host $_ -ForegroundColor Green }
    Write-Host ''
}

if ($improvements.Count -gt 0) {
    Write-Host '── Improvements ─────────────────────────────────────────────' -ForegroundColor Cyan
    $improvements | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }
    Write-Host ''
}

if ($regressions.Count -gt 0) {
    Write-Host '── Regressions ──────────────────────────────────────────────' -ForegroundColor Red
    $regressions | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    Write-Host ''
}

if ($unhandled.Count -gt 0) {
    Write-Host '── Still Unhandled ──────────────────────────────────────────' -ForegroundColor DarkYellow
    $unhandled | ForEach-Object { Write-Host $_ -ForegroundColor DarkYellow }
    Write-Host ''
}

#endregion Part 1

# ═══════════════════════════════════════════════════════════════════════════
#region Part 2 — Coverage Report (validChars.txt)
# ═══════════════════════════════════════════════════════════════════════════

Write-Host ''
Write-Host '═══════════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host '  Part 2 — Coverage Report (config/validChars.txt)'             -ForegroundColor Cyan
Write-Host '═══════════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host ''

$validCharsFile = Join-Path $configDir 'validChars.txt'
$lines = Get-Content -Path $validCharsFile

$totalLines    = $lines.Count
$validRegex    = 0
$defaultFallback = 0
$nullResult    = 0

$lineDetails = [System.Collections.Generic.List[string]]::new()

$lineNum = 0
foreach ($line in $lines) {
    $lineNum++

    if ([string]::IsNullOrWhiteSpace($line)) {
        $nullResult++
        $lineDetails.Add("  [$lineNum] (blank line) → null")
        continue
    }

    $input = [ordered]@{
        validChars = $line
        minLength  = 1
        maxLength  = 80
    }

    $result = $input | Convert-ConstraintToRegex

    if (-not $result) {
        $nullResult++
        $lineDetails.Add("  [$lineNum] $($line.Substring(0, [Math]::Min(60, $line.Length)))... → null")
    }
    elseif ($result -match '^\^\.\{1,80\}\$$') {
        # Fell back to a generic "match all" default
        $defaultFallback++
        $lineDetails.Add("  [$lineNum] $($line.Substring(0, [Math]::Min(60, $line.Length)))... → DEFAULT: $result")
    }
    else {
        $validRegex++
        $lineDetails.Add("  [$lineNum] $($line.Substring(0, [Math]::Min(60, $line.Length)))... → $result")
    }
}

Write-Host '── Coverage Summary ─────────────────────────────────────────' -ForegroundColor Yellow
Write-Host "  Total lines:           $totalLines"
Write-Host "  Valid regex produced:   $validRegex"    -ForegroundColor Green
Write-Host "  Default fallback:      $defaultFallback" -ForegroundColor DarkYellow
Write-Host "  Returned null:         $nullResult"      -ForegroundColor Red
Write-Host ''

$pctCovered = if ($totalLines -gt 0) {
    [math]::Round(($validRegex / $totalLines) * 100, 1)
} else { 0 }

Write-Host "  Coverage:              $pctCovered% ($validRegex / $totalLines)" -ForegroundColor $(
    if ($pctCovered -ge 80) { 'Green' }
    elseif ($pctCovered -ge 50) { 'Yellow' }
    else { 'Red' }
)
Write-Host ''

Write-Host '── Line-by-Line Detail ──────────────────────────────────────' -ForegroundColor Yellow
$lineDetails | ForEach-Object { Write-Host $_ }
Write-Host ''

#endregion Part 2
