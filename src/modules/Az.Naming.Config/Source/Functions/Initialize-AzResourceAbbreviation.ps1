function Initialize-AzResourceAbbreviation {
    param (
        [ScriptBlock]
        $ItemAction,

        [Switch]
        $Force
    )

    if (
        -not $Force `
        -and ${Az.Naming.Config}.ResourceAbbreviation
    ) {
        return ${Az.Naming.Config}.ResourceAbbreviation
    }

    $lines = Save-WebDocument `
        -Url ${Az.Docs}.ResourceAbbreviationUrl `
        -Force:$Force `
        -PassThru

    $result = @{}
    $currentCategory = $null
    $inTable = $false
    
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        
        # Match H2 headers starting with ## to capture categories
        if ($line -match '^##\s+(.+?)$') { 
            $currentCategory = $matches[1].Trim()
            $inTable = $false

            continue 
        }
        
        # Match table header rows with "Resource" or "Resource type"
        if (
            $line -match '^\|\s*(Resource|Asset)' `
            -and $line -match '\|'
        ) { 
            $inTable = $true

            continue 
        }
        
        # Skip separator rows
        if ($line -match '^\|\s*-+') { 
            continue 
        }
        
        # Parse table rows if we're in a table
        if (
            $inTable -and $line -match '^\|' `
            -and -not [string]::IsNullOrWhiteSpace($currentCategory)
        ) {
            $cols = $line -split '\|' `
            | ForEach-Object {
                $_.Trim()
            } `
            | Where-Object {
                $_
            }

            if ($cols.Count -ge 3) {
                $resourceName = $cols[0]
                $resourcePath = $cols[1]           # Second column is resource provider namespace
                $abbreviation = $cols[-1]          # Last column is abbreviation
                
                # Remove backticks from abbreviation and resource path
                $abbreviation = $abbreviation -replace '`', ''
                $resourcePath = $resourcePath -replace '`', ''
                
                # Remove backslash escape sequences before special characters
                $abbreviation = $abbreviation -replace '\\<', '<'
                $abbreviation = $abbreviation -replace '\\>', '>'
                $abbreviation = $abbreviation -replace '\\\*', '*'
                $resourcePath = $resourcePath -replace '\\<', '<'
                $resourcePath = $resourcePath -replace '\\>', '>'
                $resourcePath = $resourcePath -replace '\\\*', '*'
                
                # Remove any metadata in parentheses (e.g., "(kind: X)", "(mode: Y)", etc.) - future-proof
                $resourcePath = $resourcePath -replace '\s*\([^)]*\)', ''
                $resourcePath = $resourcePath.Trim()
                
                if (
                    $resourceName `
                    -and $abbreviation `
                    -and $abbreviation -notmatch '^Abbreviation' `
                    -and $abbreviation.Length -gt 0
                ) {
                    # Use abbreviation as key and full resource path as value
                    $item = @{
                        Abbreviation = $abbreviation
                        ResourcePath = $resourcePath
                        Category = $currentCategory `
                        | ConvertTo-SanitizedCategory
                    }

                    $result[$abbreviation] = @{
                        ResourcePath = $item.ResourcePath
                        Category = $item.Category
                    }

                    if ($ItemAction) {
                        & $ItemAction `
                            -InputObject $item
                    }
                }
            }
        }
    }

    ${Az.Naming.Config}.ResourceAbbreviation = $result

    return $result
}