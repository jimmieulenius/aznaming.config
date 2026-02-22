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
                    | Get-IsDictionary
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

                @{
                    Identifier = $identifier
                    Value = $_.Value
                }
            }
        }
    }
}