function Set-DictionaryItem {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [Object]
        $InputObject,

        [Parameter(
            Mandatory = $true
        )]
        [String]
        $Key,

        [Object]
        $Value,

        [Switch]
        $PassThru
    )

    if (
        $InputObject -is [Hashtable] `
        -or $InputObject -is [System.Collections.Specialized.IOrderedDictionary] `
    ) {
        $InputObject[$Key] = $Value
    }
    else {
        $InputObject `
        | Add-Member `
            -MemberType 'NoteProperty' `
            -Name $Key `
            -Value $Value `
            -Force
    }

    if ($PassThru) {
        return $InputObject
    }
}