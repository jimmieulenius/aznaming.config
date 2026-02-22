function Get-AzResourceNamePolicyConstraintFromEndpoint {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [object]
        $InputObject
    )

    $nameParameter = $InputObject.parameters `
    | Where-Object {
        $_.name -imatch 'name' `
        -and $_.in -ieq 'path'
    } `
    | Select-Object `
        -Last 1

    if (-not $nameParameter) {
        return
    }

    $resourceConfigObject = $providerConfigObject[$endpointItem.Identifier]

    if (-not $resourceConfigObject) {
        return
    }

    if ($resourceConfigObject.policy.metadata.source.type -ieq 'official docs') {
        return
    }

    $result = [ordered]@{}

    @(
        'minLength',
        'maxLength',
        'pattern'
    ) `
    | ForEach-Object {
        $value = $nameParameter.$_
        
        if ($value) {
            switch ($_) {
                ('pattern') {
                    $lengthConstraint = $value `
                    | Get-LengthConstraintFromPattern

                    @(
                        'minLength',
                        'maxLength'
                    ) `
                    | ForEach-Object {
                        if ($result.Contains($_)) {
                            return
                        }

                        $constraintsValue = $lengthConstraint.$_
                        
                        if ($constraintsValue) {
                            $result.$_ = $constraintsValue
                        }
                    }
                }
            }

            $result.$_ = $value
        }
    }

    if ($result.Keys.Count) {
        return $result
    }
}

function Get-LengthConstraintFromPattern {
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [string]
        $InputObject
    )
    
    $result = @{
        minLength = $null
        maxLength = $null
    }
    
    # Match {n,m} format
    if ($InputObject -match '\{(\d+),(\d+)\}') {
        $result.minLength = [int]$matches[1]
        $result.maxLength = [int]$matches[2]
    }
    # Match {n,} format (min only)
    elseif ($InputObject -match '\{(\d+),\}') {
        $result.minLength = [int]$matches[1]
    }
    # Match {n} format (exactly n)
    elseif ($InputObject -match '\{(\d+)\}$') {
        $result.minLength = [int]$matches[1]
        $result.maxLength = [int]$matches[1]
    }
    # Match + (min 1, no max)
    elseif ($InputObject -match '\+') {
        $result.minLength = 1
    }
    # Match * (min 0, no max)
    elseif ($InputObject -match '\*') {
        $result.minLength = 0
    }
    # Match ? (0 or 1)
    elseif ($InputObject -match '\?') {
        $result.minLength = 0
        $result.maxLength = 1
    }
    else {
        # No length constraint found
        return $null
    }
    
    return $result
}