function Get-AzResourceEndpointFromApiSpecs {
    param (
        [Parameter(Mandatory = $true)]
        [Hashtable]
        $SpecsObject,

        [Parameter(Mandatory = $true)]
        [string]
        $Provider,

        [string[]]
        $ResourcePath = @()
    )    

    if ($SpecsObject.ContainsKey('paths')) {
        $SpecsObject.paths.GetEnumerator() `
        | ForEach-Object {
            # $path = $_.Key
            $endpoint = $_.Value

            $identifier = (
                $_.Key `
                | Get-AzResourcePath `
                    -Provider $Provider
            ).Path

            $endpoint.GetEnumerator() `
            | ForEach-Object {
                if ($_.Value.deprecated) {
                    return
                }

                $endpointName = $null

                if ($_.Value.operationId -imatch 'check.*nameavailability') {
                    $endpointName = 'checkName'
                }
                elseif (
                    $_.Key -ieq 'get' `
                    -and $ResourcePath -icontains $identifier `
                    -and $endpoint.ContainsKey('put')
                ) {
                    $endpointName = 'get'
                }
                else {
                    return
                }

                if ($endpointName) {
                    # $key = (
                    #     $path `
                    #     | Get-AzResourcePath `
                    #         -Provider $Provider
                    # ).Path

                    @{
                        Identifier = $identifier
                        Value = @{
                            $endpointName = (
                                $_.Value `
                                | Merge-Dictionary `
                                    -Source @{
                                        method = $_.Key
                                    } `
                                    -PassThru
                            )
                        }
                    }
                }
            }

            # $_.Value.post.operationId,
            # $_.Value.get.operationId `
            # | Where-Object {
            #     $_ -imatch 'check.*nameavailability'
            # } `
            # | ForEach-Object {
            #     $_
            # }
        }
    }
}