function Invoke-DictionaryItem {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [Object]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [ScriptBlock]
        $ScriptBlock,

        [String]
        $Path,

        [Switch]
        $AsKeyValue,

        [Switch]
        $Force
    )

    function Invoke-Item {
        param (
            [Parameter(Mandatory = $true)]
            [String]
            $Key,

            [Object]
            $Value
        )

        $item = $AsKeyValue `
            ? @{
                Key = $Key
                Value = $Value
            }
            : $Value

        $item `
        | ForEach-Object `
            -Process $ScriptBlock
    }

    if (
        -not (
            $InputObject `
            | Get-IsDictionary
        )
    ) {
        throw "InputObject must be a dictionary."
    }

    if ($Path) {
        $currentValue = $InputObject
        # $currentPath = $null
        $pathSegments = $Path `
        | Get-PathSegment

        for ($index = 0; $index -lt $pathSegments.Count - 1; $index++) {
            $segment = $pathSegments[$index]
            $value = $currentValue.$segment
            # $currentPath = $currentPath `
            #     ? "$currentPath.[$segment]"
            #     : "[$segment]"

            if (
                -not ($value) `
                -or -not (
                    $value `
                    | Get-IsDictionary
                )
            ) {
                if (-not $Force) {
                    return
                }

                $value = [Ordered]@{}

                # Create empty object at this path
                $currentValue `
                | Set-DictionaryItem `
                    -Key $segment `
                    -Value $value

                Invoke-Item `
                    -Key $segment `
                    -Value $value
            }

            $currentValue = $value
        }

        $segment = $pathSegments[-1]

        if (
            $currentValue `
            | Get-DictionaryKey `
                -Key $segment `
        ) {
            Invoke-Item `
                -Key $segment `
                -Value $currentValue.$segment
        }
    }
    else {
        $InputObject `
        | Get-DictionaryKey `
        | ForEach-Object {
            Invoke-Item `
                -Key $_ `
                -Value $InputObject.$_
        }
    }
}