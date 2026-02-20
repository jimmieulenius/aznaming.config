function Get-IsDictionary {
    param (
        [Parameter(
            # Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [object]
        $InputObject,

        [ValidateSet(
            'Hashtable',
            'Ordered',
            'PSCustomObject'
        )]
        [string[]]
        $DictionaryType = @(
            'Hashtable',
            'Ordered',
            'PSCustomObject'
        )
    )

    if (-not $InputObject) {
        return $false
    }

    foreach ($dictionaryTypeItem in $DictionaryType) {
        switch ($dictionaryTypeItem) {
            ('Hashtable') {
                if ($InputObject -is [Hashtable]) {
                    return $true
                }
            }
            ('Ordered') {
                if ($InputObject -is [System.Collections.Specialized.IOrderedDictionary]) {
                    return $true
                }
            }
            ('PSCustomObject') {
                if ($InputObject.PSObject.TypeNames -icontains 'System.Management.Automation.PSCustomObject') {
                    return $true
                }
            }
        }
    }
}