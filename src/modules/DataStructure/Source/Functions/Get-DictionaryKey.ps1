function Get-DictionaryKey {
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
        $InputObject `
        | Test-Dictionary `
            -DictionaryType @(
                'Hashtable',
                'Ordered'
            ) `
    ) {
        $result = $InputObject.Keys
    }
    elseif (
        $InputObject `
        | Test-Dictionary `
            -DictionaryType 'PSCustomObject'
    ) {
        $result = $InputObject.PSObject.Properties.Name
    }
    else {
        Write-Error `
            -Message 'InputObject must be a dictionary.'

        return
    }

    if ($Key) {
        return $result `
        | Where-Object { $_ -ieq $Key }
    }

    return $result
}