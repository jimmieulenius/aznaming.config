function Get-DictionaryKey {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [Object]
        $InputObject,

        [String]
        $Key
    )

    if (
        $InputObject -is [Hashtable] `
        -or $InputObject -is [System.Collections.Specialized.IOrderedDictionary] `
    ) {
        $result = $InputObject.Keys
    }
    else {
        $result = $InputObject.PSObject.Properties.Name
    }

    if ($Key) {
        return $result `
        | Where-Object { $_ -ieq $Key }
    }

    return $result
}