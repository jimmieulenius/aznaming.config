function Resolve-AzApiSpecs {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [object]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [string]
        $BasePath,

        [string[]]
        $Path
    )

    function Resolve-_AzApiSpecs {
        param (
            [Parameter(
                Mandatory = $true,
                ValueFromPipeline = $true
            )]
            [object]
            $InputObject,

            [Parameter(Mandatory = $true)]
            [string]
            $BasePath,

            [string[]]
            $Path,

            [ValidateNotNull()]
            [System.Collections.Generic.HashSet[string]]
            $ResolvedRefs
        )

        function Resolve-Ref {
            param (
                [Parameter(
                    Mandatory = $true,
                    ValueFromPipeline = $true
                )]
                [string]
                $InputObject,

                [Parameter(Mandatory = $true)]
                [string]
                $BasePath
            )

            if ($InputObject -inotmatch '^([^#]*)#?(.*)$') {
                return
            }

            $filePath = $matches[1]
            $objectPath = (
                $matches[2] -split '/' `
                | ForEach-Object {
                    if (-not $_) {
                        return
                    }

                    "['$_']"
                }
            ) -join '.'

            if ($filePath) {
                $filePath = "$(
                    Split-Path `
                        -Path $BasePath `
                    -Parent
                )/$filePath"
            }
            else {
                $filePath = $BasePath
            }

            $resolvedFilePath = (
                Resolve-Path `
                    -Path $filePath
            ).Path

            $refKey = "$resolvedFilePath#$objectPath"

            if (-not $ResolvedRefs.Add($refKey)) {
                return
            }

            $refObject = Get-Content `
                -Path $filePath `
                -Raw `
            | ConvertFrom-Json `
                -AsHashtable

            if ($objectPath) {
                return (
                    $refObject `
                    | Get-DictionaryItem `
                        -Path $objectPath
                ).Value `
                | Resolve-_AzApiSpecs `
                    -BasePath $filePath `
                    -ResolvedRefs $ResolvedRefs
            }

            return $refObject `
            | Resolve-_AzApiSpecs `
                -BasePath $filePath `
                -ResolvedRefs $ResolvedRefs
        }

        $toUpdate = @{}
        $scriptBlock = {
            $item = $_

            switch ($item.Path) {
                { $_ -imatch "$([Regex]::Escape("['`$ref']"))$" } {
                    $toUpdate[$item.Path] = $item.Value
                }
            }
        }

        (
            $Path `
                ? $Path `
                : (
                    $InputObject `
                    | Get-DictionaryKey
                )
        ) `
        | ForEach-Object {
            $InputObject `
            | Invoke-DictionaryItem `
                -Path $_ `
                -ScriptBlock $scriptBlock `
                -Recurse `
                -ErrorAction 'SilentlyContinue'
        }

        $toUpdate.GetEnumerator() `
        | ForEach-Object {
            $value = $_.Value `
            | Resolve-Ref `
                -BasePath $BasePath

            if (-not $value) {
                return
            }

            $objectPath = $null

            $_.Key `
            | Get-PathSegment `
            | Select-Object `
                -SkipLast 1 `
            | ForEach-Object {
                $objectPath = $objectPath `
                | Add-PathSegment `
                    -PathSegment $_
            }

            if ($objectPath) {
                Invoke-DictionaryItem `
                    -InputObject $InputObject `
                    -Path $objectPath `
                    -ScriptBlock {
                        $_.Value `
                        | Merge-Dictionary `
                            -Source $value `
                        | Out-Null

                        $_.Value.Remove('$ref')
                    }
            }
        }

        # Flatten x-ms-client-flatten entries
        $toFlatten = [ordered]@{}
        $flattenScriptBlock = {
            $flattenItem = $_

            if (
                (
                    $flattenItem.Value `
                    | Get-IsDictionary
                ) `
                -and $flattenItem.Value.ContainsKey('x-ms-client-flatten') `
                -and $flattenItem.Value['x-ms-client-flatten'] -eq $true `
                -and (
                    $flattenItem.Path `
                    | Get-PathSegment `
                    | Select-Object `
                        -Last 1
                ).IdentifierType -ine 'Index'
            ) {
                $toFlatten[$flattenItem.Path] = $flattenItem.Value
            }
        }

        (
            $Path `
                ? $Path `
                : (
                    $InputObject `
                    | Get-DictionaryKey
                )
        ) `
        | ForEach-Object {
            $InputObject `
            | Invoke-DictionaryItem `
                -Path $_ `
                -ScriptBlock $flattenScriptBlock `
                -Recurse `
                -ErrorAction 'SilentlyContinue'
        }

        $toFlatten.GetEnumerator() `
        | Sort-Object {
            (
                $_.Key `
                | Get-PathSegment
            ).Count
        } -Descending `
        | ForEach-Object {
            $flattenValue = $_.Value

            $flattenSource = [ordered]@{}

            $flattenValue.GetEnumerator() `
            | Where-Object {
                $_.Key -ine 'x-ms-client-flatten'
            } `
            | ForEach-Object {
                $flattenSource[$_.Key] = $_.Value
            }

            if (-not $flattenSource.Count) {
                return
            }

            $flattenParentPath = $null
            $flattenSegments = $_.Key `
            | Get-PathSegment

            $flattenSegments `
            | Select-Object `
                -SkipLast 1 `
            | ForEach-Object {
                $flattenParentPath = $flattenParentPath `
                | Add-PathSegment `
                    -PathSegment $_
            }

            $flattenKey = (
                $flattenSegments `
                | Select-Object `
                    -Last 1
            ).Identifier

            if ($flattenParentPath) {
                Invoke-DictionaryItem `
                    -InputObject $InputObject `
                    -Path $flattenParentPath `
                    -ScriptBlock {
                        $_.Value `
                        | Merge-Dictionary `
                            -Source $flattenSource `
                        | Out-Null

                        $_.Value.Remove($flattenKey)
                    }
            }
            else {
                $InputObject `
                | Merge-Dictionary `
                    -Source $flattenSource `
                | Out-Null

                $InputObject.Remove($flattenKey)
            }
        }

        return $InputObject
    }

    $ResolvedRefs = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    return $InputObject `
    | Resolve-_AzApiSpecs `
        -BasePath $BasePath `
        -Path $Path `
        -ResolvedRefs $ResolvedRefs
}