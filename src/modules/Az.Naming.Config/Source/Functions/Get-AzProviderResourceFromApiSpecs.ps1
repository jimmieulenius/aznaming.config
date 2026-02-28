function Get-AzProviderResourceFromApiSpecs {
    param (
        [Parameter(Mandatory = $true)]
        [Hashtable]
        $SpecsObject,

        [Parameter(Mandatory = $true)]
        [string]
        $Provider
    )

    $SpecsObject.paths `
    | ForEach-Object {
        $_.GetEnumerator() `
        | ForEach-Object {
            $path = $_.Key

            if (
                (
                    $_.Value `
                    | Test-Dictionary
                ) `
                -and (
                    $_.Value `
                    | Get-DictionaryKey `
                        -ErrorAction 'SilentlyContinue'
                ) -icontains 'put'
            ) {
                $identifier = (
                    $path `
                    | Get-AzResourcePath `
                        -Provider $Provider
                ).Path

                if (
                    -not (
                        $identifier `
                        | Split-AzResourcePath `
                            -Entity
                    )
                ) {
                    return
                }

                @{
                    Identifier = $identifier
                    Value = $_.Value
                }
            }
        }
    }
}