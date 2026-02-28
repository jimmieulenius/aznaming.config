function Set-DictionaryItem {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [object]
        $InputObject,

        [Parameter(
            Mandatory = $true
        )]
        [string]
        $Key,

        [object]
        $Value,

        [Switch]
        $PassThru
    )

    if (
        $InputObject `
        | Test-Dictionary `
            -DictionaryType @(
                'Hashtable',
                'Ordered'
            )
    ) {
        $InputObject[$Key] = $Value
    }
    elseif (
        $InputObject `
        | Test-Dictionary `
            -DictionaryType 'PSCustomObject'
    ) {
        $InputObject `
        | Add-Member `
            -MemberType 'NoteProperty' `
            -Name $Key `
            -Value $Value `
            -Force
    }
    else {
        Write-Error `
            -Message 'InputObject must be a dictionary.'

        return
    }

    if ($PassThru) {
        return $InputObject
    }
}