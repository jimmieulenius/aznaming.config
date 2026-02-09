function Resolve-AzApiSpecs {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [Hashtable]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [string]
        $BasePath
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
            ).Value
        }

        return $refObject
    }

    $toUpdate = @{}
    $scriptBlock = {
        $item = $_

        switch ($item.Path) {
            { $_ -imatch "$([Regex]::Escape("['`$ref']"))$"} {
                $toUpdate[$item.Path] = $item.Value
            }
        }
    }

    @(
        'parameters',
        'responses'
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

        $path = $null

        $_.Key `
        | Get-PathSegment `
        | Select-Object `
            -SkipLast 1 `
        | ForEach-Object {
           $path =  $path `
            | Add-PathSegment `
                -PathSegment $_
        }

        Invoke-DictionaryItem `
            -InputObject $InputObject `
            -Path $path `
            -ScriptBlock {
                $_.Value `
                | Merge-Dictionary `
                    -Source $value `
                | Out-Null

                $_.Value.Remove('$ref')
            }
    }

    return $InputObject
}