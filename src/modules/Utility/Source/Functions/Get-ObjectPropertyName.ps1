function Get-ObjectPropertyName {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [Object]
        $InputObject
    )

    if (
        $InputObject -is [Hashtable] `
        -or $InputObject -is [System.Collections.Specialized.IOrderedDictionary] `
    ) {
        return $InputObject.Keys
    }

    return $InputObject.PSObject.Properties.Name
}