function Add-PathSegment {
    param (
        [Parameter(ValueFromPipeline = $true)]
        [string]
        $InputObject,

        [PSTypeName('DataStructure.PathSegment')]
        $PathSegment
    )

    $separator = $null

    switch ($PathSegment.IdentifierType) {
        ('Property') {
            $segment = "'$($PathSegment.Identifier)'"
            $separator = if ($InputObject) {
                '.'
            }
            else {
                $null
            }
        }
        ('Index') {
            $segment = $PathSegment.Identifier
        }
    }

    return "$($InputObject)$($separator)[$segment]"
}