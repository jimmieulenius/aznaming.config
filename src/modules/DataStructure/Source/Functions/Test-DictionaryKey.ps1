function Test-DictionaryKey {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [object]
        $InputObject,

        [string]
        $Key
    )

    if (
        -not (
            Test-Dictionary `
                -InputObject $InputObject
        )
    ) {
        Write-Error `
            -Message 'InputObject must be a dictionary.'

        return
    }

    if (
        Get-DictionaryKey `
            -InputObject $InputObject `
            -Key $Key
    ) {
        return $true
    }

    return $false
}