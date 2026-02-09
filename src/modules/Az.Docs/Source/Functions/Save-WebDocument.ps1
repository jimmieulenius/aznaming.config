function Save-WebDocument {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Url,

        [Switch]
        $Force,

        [Switch]
        $PassThru
    )

    $tempDir = "$($env:TEMP)/Azure.Docs"

    New-Item `
        -ItemType 'Directory' `
        -Path $tempDir `
        -Force `
        -ErrorAction 'SilentlyContinue' `
    | Out-Null

    $cachePath = "$tempDir/$(
        Split-Path `
            -Path $Url `
            -Leaf
    )"

    if ($Force -or -not (Test-Path $cachePath)) {
        Invoke-WebRequest `
            -Uri $Url `
            -OutFile $cachePath `
            -UseBasicParsing
    }

    if ($PassThru) {
        return Get-Content `
            -Path $cachePath `
            -Encoding 'UTF8'
    }
}