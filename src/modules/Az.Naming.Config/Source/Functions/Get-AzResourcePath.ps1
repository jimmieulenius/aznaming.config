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

    $entity = (
        (
            $InputObject -split $Provider
        )[1] `
        -replace '\{[^}]*\}', '' `
        -replace '/+', '/'
    ).Trim('/')

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