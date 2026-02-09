function Add-JsonLine {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter(Mandatory = $true)]
        [Hashtable]
        $Value
    )

    if (
        -not (
            Test-Path `
            -Path $Path
        )
    ) {
        New-Item `
            -Path $Path `
            -ItemType File `
            -Force
    }

    Add-Content `
        -Path $Path `
        -Value (
            $Value `
            | ConvertTo-Json `
                -Depth 100 `
                -Compress
        )
}