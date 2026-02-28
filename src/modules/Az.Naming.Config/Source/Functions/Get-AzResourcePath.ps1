function Get-AzResourcePath {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [string]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [string]
        $Provider
    )

    $InputObject = $InputObject `
        -replace '\{[^}]*\}', '' `
        -replace '/+', '/' `
        -replace ' ', ''

    if ($InputObject -imatch [regex]::Escape($Provider)) {
        $entity = (
            $InputObject -split $Provider
        )[1]
    }
    else {
        $entity = $InputObject
    }

    $entity = $entity.Trim('/')

    # $entity = (
    #     $entity `
    #     -replace '\{[^}]*\}', '' `
    #     -replace '/+', '/' `
    #     -replace ' ', ''
    # ).Trim('/')

    return @{
        Provider = $Provider
        Entity = $entity
        Path = "$Provider/$entity"
    }

    # return (
    #     "$Provider$(
    #         (
    #             $InputObject -split $Provider
    #         )[1]
    #     )" `
    #     -replace '\{[^}]*\}', '' `
    #     -replace '/+', '/'
    # ).TrimEnd('/')
}