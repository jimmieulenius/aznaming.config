function ConvertTo-SanitizedCategory {
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true)]
        [String]
        $InputObject
    )

    if (-not $InputObject) {
        return "others"
    }

    return (
        $InputObject `
            -replace '[^\w\s\-]', '' `
            -replace '\s+', '-' `
            -replace '-+', '-'
    ). `
    ToLower(). `
    Trim('-')
}