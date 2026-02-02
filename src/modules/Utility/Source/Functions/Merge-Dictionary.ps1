enum MergeStatus {
    Skipped
    Merged
    Created
}

function Merge-Dictionary {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [Object]
        $InputObject,

        [Object]
        $Source,

        [String]
        $Path,

        [Switch]
        $PassThru
    )

    @{
        InputObject = $InputObject
        Source = $Source
    }.GetEnumerator() `
    | ForEach-Object {
        if (
            -not (
                $_.Value `
                | Get-IsDictionary
            )
        ) {
            throw (
                "$($_.Key) must be a dictionary."
            )
        }
    }

    if (
        -not (
            $Source `
            | Get-DictionaryKey
        )
    ) {
        return $InputObject
    }

    $status = [MergeStatus]::Skipped
    $currentObj = $InputObject

    if ($Path) {
        $pathSegments = $Path `
        | Get-PathSegment

        foreach ($segment in $pathSegments[0..($pathSegments.Count - 1)]) {
            $value = $currentObj.$segment

            if (
                -not ($value) `
                -or -not (
                    $value `
                    | Get-IsDictionary
                )
            ) {
                $value = [Ordered]@{}

                # Create empty object at this path
                $currentObj `
                | Set-DictionaryItem `
                    -Key $segment `
                    -Value $value

                $status = [MergeStatus]::Created
            }

            $currentObj = $value
        }
    }

    $targetKey = $currentObj `
    | Get-DictionaryKey

    foreach ($keyItem in (
        $Source `
        | Get-DictionaryKey
    )) {
        $shouldProceed = $true
        $sourceValue = $Source.$keyItem

        if ($targetKey -icontains $keyItem) {
            $targetValue = $currentObj.$keyItem

            if (
                (
                    $targetValue `
                    | Get-IsDictionary
                ) `
                -and (
                    $sourceValue `
                    | Get-IsDictionary
                )
            ) {
                $currentObj
                | Set-DictionaryItem `
                    -Key $keyItem `
                    -Value (
                        $targetValue `
                        | Merge-Dictionary `
                            -Source $sourceValue `
                            -PassThru
                    )

                $shouldProceed = $false

                if ($status -lt [MergeStatus]::Created) {
                    $status = [MergeStatus]::Merged
                }
            }
        }

        if ($shouldProceed) {
            $currentObj `
            | Set-DictionaryItem `
                -Key $keyItem `
                -Value $Source.$keyItem
        }
    }

    if ($PassThru) {
        return $InputObject
    }

    return $status
}