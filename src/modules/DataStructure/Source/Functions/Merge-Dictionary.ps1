enum MergeStatus {
    Skipped
    Merged
    Created
}

function Merge-Dictionary {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [object]
        $InputObject,

        [object]
        $Source,

        [string]
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
            Write-Error `
                -Message "$($_.Key) must be a dictionary."
        }
    }

    if (
        -not (
            $Source `
            | Get-DictionaryKey `
                -ErrorAction 'SilentlyContinue'
        )
    ) {
        return $InputObject
    }

    $status = [MergeStatus]::Skipped
    $currentObj = $InputObject

    if ($Path) {
        $pathSegments = $Path `
        | Get-PathSegment
        $pathSegmentParent = $null

        foreach ($pathSegmentsItem in $pathSegments[0..($pathSegments.Count - 1)]) {
            switch ($pathSegmentsItem.IdentifierType) {
                ('Property') {
                    $value = $currentObj[$pathSegmentsItem.Identifier]
                }
                ('Index') {
                    $value = $currentObj[$pathSegmentsItem.Identifier]
                }
            }

            if (
                -not $value `
                -or (
                    $pathSegmentsItem.ContainerType -eq 'Object' `
                    -and -not (
                        $value `
                        | Get-IsDictionary
                    )
                ) `
                -or (
                    $pathSegmentsItem.ContainerType -eq 'Array' `
                    -and -not (
                        $value `
                        | Get-IsArray
                    )
                )
            ) {
                switch ($pathSegmentsParent.ContainerType) {
                    ('Array') {
                        $value ??= @()

                        if ($value.Count -le $pathSegmentsItem.Identifier) {
                            for ($i = $value.Count; $i -le $pathSegmentsItem.Identifier; $i++) {
                                $value += $null
                            }
                        }
                    }
                    default {
                        $value ??= [Ordered]@{}
                    }
                }

                $status = [MergeStatus]::Created
            }

            switch ($pathSegmentsItem.IdentifierType) {
                ('Property') {
                    $currentObj `
                    | Set-DictionaryItem `
                        -Key $pathSegmentsItem.Identifier `
                        -Value $value
                }
                ('Index') {
                    $currentObj[$pathSegmentsItem.Identifier] = $value
                }
            }

            $currentObj = $value
            $pathSegmentParent = $pathSegmentsItem
        }
    }

    $targetKey = $currentObj `
    | Get-DictionaryKey `
        -ErrorAction 'SilentlyContinue'

    foreach (
        $keyItem in (
            $Source `
            | Get-DictionaryKey `
                -ErrorAction 'SilentlyContinue'
        )
    ) {
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