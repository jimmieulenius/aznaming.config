function New-AzResourceNamePolicy {
    <#
    .SYNOPSIS
        Creates an Azure resource name policy hashtable.
    .DESCRIPTION
        Builds a policy object containing constraints (minLength, maxLength, validChars, regex),
        defaults (RESOURCE_TYPE abbreviation), and source metadata. When a validChars description
        is provided but no explicit regex, the function calls Convert-ConstraintToRegex to
        generate the regex pattern automatically.
    .PARAMETER MinLength
        Minimum allowed name length. Falls back to $script:DefaultMinLength if not specified.
    .PARAMETER MaxLength
        Maximum allowed name length. Falls back to $script:DefaultMaxLength if not specified.
    .PARAMETER ValidChars
        Descriptive text of allowed characters (e.g. "Alphanumerics and hyphens").
    .PARAMETER Regex
        An explicit regex pattern. If provided, Convert-ConstraintToRegex is skipped.
    .PARAMETER Abbreviation
        The resource type abbreviation used as a naming default.
    .PARAMETER Source
        The origin of the naming rule (e.g. "official docs", "official api specs").
    .OUTPUTS
        [ordered] hashtable with keys: constraints, defaults, source.
    #>
    [CmdletBinding()]
    param (
        [int]
        $MinLength,

        [int]
        $MaxLength,

        [string]
        $ValidChars,

        [string]
        $Pattern,

        [string]
        $Abbreviation,

        [hashtable]
        $Source
    )

    $constraints = [ordered]@{}

    @{
        minLength = $MinLength
        maxLength = $MaxLength
        pattern = $Pattern
        validChars = $ValidChars
    }.GetEnumerator() `
    | ForEach-Object {
        if ($_.Value) {
            $constraints[$_.Key] = $_.Value
        }
    }

    # $constraints = [ordered]@{
    #     minLength = $MinLength `
    #         ? $MinLength `
    #         : $script:DefaultMinLength
    #     maxLength = $MaxLength `
    #         ? $MaxLength `
    #         : $script:DefaultMaxLength
    #     validChars = $ValidChars
    #     pattern = $Pattern
    # }

    if (
        $constraints.validChars `
        -and -not $constraints.pattern
    ) {
        $constraints.pattern = $constraints `
        | Convert-ConstraintToRegex
    }

    $constraints.Remove('validChars') `
    | Out-Null

    if (-not $constraints.Keys.Count) {
        $constraints = $null
    }

    $metadata = [ordered]@{}

    @{
        source = $Source
        validChars = $ValidChars
    }.GetEnumerator() `
    | ForEach-Object {
        if ($_.Value) {
            $metadata[$_.Key] = $_.Value
        }
    }

    if (-not $metadata.Keys.Count) {
        $metadata = $null
    }

    $result = [ordered]@{}

    @{
        metadata = $metadata
        constraints = $constraints
        defaults = @{
            RESOURCE_TYPE = $Abbreviation
        }
    }.GetEnumerator() `
    | ForEach-Object {
        if ($_.Value) {
            $result[$_.Key] = $_.Value
        }
    }

    return $result

    # return [ordered]@{
    #     metadata = @{
    #         source = $Source
    #         validChars = $ValidChars
    #     }
    #     constraints = $constraints
    #     defaults = @{
    #         RESOURCE_TYPE = $Abbreviation
    #     }
    # }
}