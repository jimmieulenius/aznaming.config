# Load the Convert-ConstraintToRegex module
$functionPath = 'c:\Users\admin\Source\Repos\aznaming.config\src\modules\Az.Naming.Config\Source\Functions\Convert-ConstraintToRegex.ps1'
. $functionPath

# Read the validChars.txt file
$validCharsPath = 'c:\Users\admin\Source\Repos\aznaming.config\config\validChars.txt'
$validCharsLines = @(Get-Content -Path $validCharsPath -Encoding UTF8)

# Output file paths
$outputPath = 'c:\Users\admin\Source\Repos\aznaming.config\config\validChars-regex.json'
$reportPath = 'c:\Users\admin\Source\Repos\aznaming.config\config\validChars-regex-report.txt'

# Process each line
$results = @()
$lineNumber = 0

foreach ($line in $validCharsLines) {
    $lineNumber++
    Write-Progress -Activity "Processing validChars" -Status "Line $lineNumber of $($validCharsLines.Count)" -PercentComplete ($lineNumber / $validCharsLines.Count * 100)
    
    # Create hashtable for the constraint
    $constraintHashtable = @{
        validChars = $line
        minLength  = 1
        maxLength  = 80
    }
    
    # Convert to regex
    try {
        $regex = Convert-ConstraintToRegex -InputObject $constraintHashtable
        $status = if ($regex) { "SUCCESS" } else { "NO_REGEX_GENERATED" }
    }
    catch {
        $regex = $null
        $status = "ERROR: $($_.Exception.Message)"
    }
    
    # Store result
    $results += [PSCustomObject]@{
        LineNumber      = $lineNumber
        ValidationText  = $line
        GeneratedRegex  = $regex
        Status          = $status
    }
}

Write-Progress -Activity "Processing validChars" -Completed

# Convert results to JSON for storage
$jsonOutput = $results | ConvertTo-Json -Depth 10
$jsonOutput | Out-File -FilePath $outputPath -Encoding UTF8 -Force

# Create a detailed report
$report = @()
$report += "# ValidChars to Regex Conversion Report"
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "Total Lines Processed: $($results.Count)"
$report += ""
$report += "## Summary Statistics"
$report += "- Successful conversions: $($results | Where-Object { $_.Status -eq 'SUCCESS' } | Measure-Object | Select-Object -ExpandProperty Count)"
$report += "- No regex generated: $($results | Where-Object { $_.Status -eq 'NO_REGEX_GENERATED' } | Measure-Object | Select-Object -ExpandProperty Count)"
$report += "- Errors: $($results | Where-Object { $_.Status -like 'ERROR*' } | Measure-Object | Select-Object -ExpandProperty Count)"
$report += ""
$report += "## Detailed Results"
$report += ""

foreach ($result in $results) {
    $report += "### Line $($result.LineNumber)"
    $report += "**Validation Text:**"
    $report += "$($result.ValidationText)"
    $report += ""
    $report += "**Status:** $($result.Status)"
    $report += ""
    if ($result.GeneratedRegex) {
        $report += "**Generated Regex:**"
        $report += "``````"
        $report += "$($result.GeneratedRegex)"
        $report += "``````"
    }
    else {
        $report += "*No regex generated for this constraint.*"
    }
    $report += ""
}

$report -join "`n" | Out-File -FilePath $reportPath -Encoding UTF8 -Force

Write-Host "Processing completed!"
Write-Host "JSON results saved to: $outputPath"
Write-Host "Report saved to: $reportPath"
Write-Host ""
Write-Host "Summary:"
Write-Host "- Total lines: $($results.Count)"
Write-Host "- Successful: $($results | Where-Object { $_.Status -eq 'SUCCESS' } | Measure-Object | Select-Object -ExpandProperty Count)"
Write-Host "- No regex: $($results | Where-Object { $_.Status -eq 'NO_REGEX_GENERATED' } | Measure-Object | Select-Object -ExpandProperty Count)"
Write-Host "- Errors: $($results | Where-Object { $_.Status -like 'ERROR*' } | Measure-Object | Select-Object -ExpandProperty Count)"
