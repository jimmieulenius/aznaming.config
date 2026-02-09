function Get-AzProviderResourceFromApiSpecs {
    param (
        [Parameter(Mandatory = $true)]
        [Hashtable]
        $SpecsObject,

        [Parameter(Mandatory = $true)]
        [string]
        $Provider,

        [Switch]
        $AsKeyValue
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
                $key = (
                    $path `
                    | Get-AzResourcePath `
                        -Provider $Provider
                ).Path

                if ($AsKeyValue) {
                    @{
                        Key = $key
                        Value = $_.Value
                    }
                }
                else {
                    $key
                }
            }
        }
    }
}