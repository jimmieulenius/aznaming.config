function Test-Array {
    param (
        [Parameter(ValueFromPipeline = $true)]
        [object]
        $InputObject,

        [ValidateSet(
            'Array',
            'Enumerable'
        )]
        [string[]]
        $ArrayType = @(
            'Array',
            'Enumerable'
        )
    )

    if ($null -eq $InputObject) {
        return $false
    }

    foreach ($arrayTypeItem in $ArrayType) {
        switch ($arrayTypeItem) {
            ('Array') {
                if ($InputObject -is [array]) {
                    return $true
                }
            }
            # ('Enumerable') {
            #     if ($InputObject -is [System.Collections.IEnumerable]) {
            #         return -not (
            #             $InputObject `
            #             | Test-Dictionary
            #         )
            #     }
            # }
        }
    }
}