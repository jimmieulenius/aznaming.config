function New-AzResourceAbbreviation {
    [CmdletBinding()]
    param (
        [string]
        $ResourcePath,

        [switch]
        $AsTodo
    )

    if (-not $ResourcePath) {
        Write-Error 'ResourcePath is required.'

        return
    }

    # Extract and generate abbreviations for all components
    $components = @{}

    foreach ($componentType in @('Provider', 'Entity', 'EntityLeaf')) {
        $parameterObject = @{ $componentType = $true }
        $value = $ResourcePath `
        | Split-AzResourcePath @parameterObject
        
        if ($value) {
            $components[$componentType] = $value
            $components["${componentType}Abbreviation"] = $value `
            | Get-ResourceComponentAbbreviation
        }
    }

    # Validate we have the minimum required component
    if (-not $components.EntityLeafAbbreviation) {
        if ($AsTodo) {
            return '<TODO>'
        }

        Write-Error 'Could not generate abbreviation from ResourcePath components.'

        return
    }

    # Build candidate abbreviations in priority order (shortest to longest)
    $candidates = @(
        $components.EntityLeafAbbreviation
    )

    if ($components.ProviderAbbreviation `
        -and $components.EntityLeafAbbreviation
    ) {
        $candidates += "$($components.ProviderAbbreviation)$($components.EntityLeafAbbreviation)"
    }

    # Try each candidate to find one not already in use
    $result = $null

    foreach ($candidate in $candidates) {
        if ($AsTodo) {
            $candidate = "<TODO:$candidate>"
        }

        if (-not ${Az.Naming.Config}.ResourceAbbreviation.ContainsKey($candidate)) {
            # $result = if ($AsTodo) {
            #     "<TODO:$candidate>"
            # }
            # else {
            #     $candidate
            # }

            $result = $candidate

            ${Az.Naming.Config}.ResourceAbbreviation[$result] = @{
                ResourcePath = $ResourcePath
            }

            break
        }
    }

    # If all candidates are taken, append a numeric suffix
    if (-not $result) {
        $baseResult = $candidates[-1]  # Use longest candidate as base
        $counter = 2
        $maxAttempts = 1000

        while ($counter -le $maxAttempts) {
            $candidate = "$baseResult$counter"

            if ($AsTodo) {
                $candidate = "<TODO:$candidate>"
            }

            if (-not ${Az.Naming.Config}.ResourceAbbreviation.ContainsKey($candidate)) {
                # $result = if ($AsTodo) {
                #     "<TODO:$candidate>"
                # }
                # else {
                #     $candidate
                # }

                $result = $candidate

                break
            }

            $counter++
        }

        if (-not $result) {
            if ($AsTodo) {
                return '<TODO>'
            }

            Write-Error "Could not generate unique abbreviation after $maxAttempts attempts."

            return
        }
    }

    # if ($AsTodo) {
    #     $result = "<TODO:$result>"
    # }

    return $result
}

# Helper function to generate abbreviation from a resource component
function Get-ResourceComponentAbbreviation {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [string]
        $InputObject
    )

    if (-not $InputObject) {
        return $null
    }

    $abbreviation = ''

    # Add first character if lowercase (e.g., 'mySql' -> 'm')
    if ([char]::IsLower($InputObject[0])) {
        $abbreviation = $InputObject[0]
    }

    # Add all uppercase letters (camelCase extraction: 'mySQL' -> 'SQL', 'ServiceBus' -> 'SB')
    $camelMatches = [regex]::Matches($InputObject, '[A-Z]')

    if ($camelMatches.Count) {
        foreach ($match in $camelMatches) {
            $abbreviation += $match.Value
        }
    }

    # Fallback: if no camelCase found, use first character
    if (-not $abbreviation) {
        $abbreviation = $InputObject[0]
    }

    $abbreviation = $abbreviation.ToString().ToLower()

    # Ensure minimum 2 characters
    if ($abbreviation.Length -lt 2) {
        # Try to add the next character from the input
        if ($InputObject.Length -gt 1) {
            $abbreviation += $InputObject[1].ToString().ToLower()
        }
    }

    return $abbreviation
}