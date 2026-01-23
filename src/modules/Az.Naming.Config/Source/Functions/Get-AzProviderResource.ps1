function Get-AzProviderResource {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Provider,

        [Parameter(Mandatory = $true)]
        [Hashtable]
        $SpecsObject
    )

    $result = [System.Collections.Generic.List[String]]::new()

    $SpecsObject.paths `
    | ForEach-Object {
        $_.GetEnumerator() `
        | ForEach-Object {
            $path = $_.Key

            if (
                (
                    $_.Value `
                    | Get-IsObject
                ) `
                -and (
                    $_.Value `
                    | Get-ObjectPropertyName
                ) -icontains 'put'
            ) {
                $item = (
                    "$Provider$(
                        (
                            $path -split $Provider
                        )[1]
                    )" `
                    -replace '\{[^}]*\}', '' `
                    -replace '/+', '/'
                ).TrimEnd('/')

                $result.Add($item)
            }
        }
    }

    return $result.ToArray()
}