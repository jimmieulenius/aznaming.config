function Split-AzResourcePath {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [string]
        $InputObject,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Provider"
        )]
        [switch]
        $Provider,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Entity"
        )]
        [switch]
        $Entity,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "EntityLeaf"
        )]
        [switch]
        $EntityLeaf
    )

    switch ($PSCmdlet.ParameterSetName) {
        ('Provider') {
            return (
                $InputObject -split '/'
            )[0]
        }
        ('Entity') {
            return (
                $InputObject -split '/' `
                | Select-Object `
                    -Skip 1
            ) -join '/'
        }
        ('EntityLeaf') {
            return (
                $InputObject -split '/'
            )[-1]
        }
    }
}