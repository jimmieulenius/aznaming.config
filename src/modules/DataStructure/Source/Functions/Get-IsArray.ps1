function Get-IsArray {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
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
            #             | Get-IsDictionary
            #         )
            #     }
            # }
        }
    }
}