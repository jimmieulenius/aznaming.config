function Get-IsDictionary {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [Object]
        $InputObject
    )

    return $InputObject -is [Hashtable] `
        -or $InputObject -is [System.Collections.Specialized.IOrderedDictionary] `
        -or $InputObject.PSObject.TypeNames -icontains 'System.Management.Automation.PSCustomObject'
}